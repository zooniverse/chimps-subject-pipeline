require 'aws-sdk'
require 'base64'
require 'bson'
require 'json'
require 'mimemagic'
require 'shellwords'
require 'yaml'

def close_streams(*args)
  args.each{ |arg| arg.close }
end

def mime_type(path)
  ext = File.extname(path)
  case ext
  when ".avi"
    "video/x-msvideo"
  when ".jpg"
    "image/jpeg"
  when ".json"
    "application/json"
  when ".mp4"
    "video/mp4"
  when ".webm"
    "video/webm"
  else
    other_extension = MimeMagic.by_extension(ext)
    if other_extension.respond_to? 'type'
      other_extension.type
    else
      "application/octet-stream"
    end
  end
end

config_path = File.join Dir.pwd, 'consumer.yml'
unless ARGV[0] == '--local'
  `aws s3 cp s3://zooniverse-code/production_configs/chimps-data-processing/consumer.yml #{ config_path }`
end
config = YAML.load_file config_path

Aws.config.update({
  region: config['aws']['region'],
  credentials: Aws::Credentials.new(config['aws']['key'], config['aws']['secret'])
})

s3 = Aws::S3::Client.new
poller = Aws::SQS::QueuePoller.new(config['queue_url'])

`rm -rf #{ config['temp_path'] }`
`rm -rf #{ config['output']['local_path'] }`

print "Starting...\n"
poller.poll(max_number_of_messages: config['concurrency']) do |messages|
  `mkdir -p #{ config['temp_path'] }`
  `mkdir -p #{ config['output']['local_path'] }`

  subjects = []
  messages.each do |message|
    subjects << JSON.parse(Base64.decode64(message.body))
  end

  unique_files = subjects.collect { |subject| subject['file_location'] }.uniq
  download_threads = []
  unique_files.each do |unique_file|
    download_threads << Thread.new do
      response_target = File.join(config['temp_path'], unique_file)
      `mkdir -p '#{ File.dirname response_target }'`

      bucket, *key = unique_file.split '/'
      s3.get_object(
        response_target: response_target,
        bucket: bucket,
        key: key.join('/')
      )
    end
  end
  download_threads.each &:join

  # Encode!
  starting_time = Time.now

  subject_threads = []
  subjects.each do |subject|
    subject_threads << Thread.new do
      print "Processing #{ subject['bson_id'] }\n"
      bucket, *key = subject['file_location'].split '/'

      bson_id = subject['bson_id']
      start_time = subject['start_time']
      duration = subject['duration']

      source_file = File.join config['temp_path'], subject['file_location']
      subject_output_path = File.join config['output']['local_path'], bson_id
      `mkdir -p #{ subject_output_path }/previews`

      # h264
      cmd = "ffmpeg -nostdin -ss #{ start_time } -i '#{ source_file }' -y -to #{ duration } -c:v libx264 -preset medium -crf 23 -vf scale=\"720:trunc(ow/a/2)*2\" -r 24 -pix_fmt yuv420p -threads 0 -c:a libmp3lame -q:a 6 '#{ subject_output_path }/#{ bson_id }.mp4'"
      system cmd, [:out, :err] => '/dev/null'

      # webm
      cmd = "ffmpeg -nostdin -ss #{ start_time } -i '#{ source_file }' -y -to #{ duration } -c:v libvpx -b:v 500k -crf 30 -vf scale=\"720:trunc(ow/a/2)*2\" -r 24 -pix_fmt yuv420p -threads 0 -c:a libvorbis '#{ subject_output_path }/#{ bson_id }.webm'"
      system cmd, [:out, :err] => '/dev/null'

      (0..subject['duration']).each do |second|
        cmd = "ffmpeg -nostdin -ss #{ start_time + second } -i \"#{ source_file }\" -y -r 1 -to 1 #{subject_output_path }/previews/#{ bson_id }_#{ second }.jpg"
        system cmd, [:out, :err] => '/dev/null'
      end

      # Upload to S3
      files_to_upload = Dir["#{ config['output']['local_path'] }/#{ bson_id }/**/*.*"]
      files_to_upload.each do |file_to_upload|
        key = File.join config['output']['key'], file_to_upload.gsub(config['output']['local_path'], '')

        s3.put_object(
          body: File.open(file_to_upload, 'r'),
          bucket: config['output']['bucket'],
          key: key,
          content_type: mime_type(file_to_upload),
          acl: 'public-read'
        )
      end
    end
  end
  subject_threads.each &:join

  `rm -rf #{ config['temp_path'] }`
  `rm -rf #{ config['output']['local_path'] }`

  ending_time = Time.now
  print "Batch: #{ ending_time - starting_time }\n\n"
end
