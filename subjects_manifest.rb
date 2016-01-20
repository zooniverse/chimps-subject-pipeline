require 'aws'
require 'bson'
require 'connection_pool'
require 'json'
require 'mysql2'
require 'open3'
require 'shellwords'
require 'yaml'

class ErrorLogger
  def initialize
    @error_file = File.open File.join(Dir.pwd, 'errors.txt'), 'w'
  end

  def log(file, message)
    @error_file.puts "#{ file }, #{ message }"
  end
end

DESIRED_SUBJECT_LENGTH = 15

config = YAML.load_file File.join Dir.pwd, 'config.yml'
mysql = ConnectionPool.new(size: 4) {
  Mysql2::Client.new(
    host: config['mysql']['hostname'],
    username: config['mysql']['username'],
    password: config['mysql']['password'],
    database: config['mysql']['database']
  )
}
logger = ErrorLogger.new

video_files = Dir["#{ config['input_path'] }/**/*.{AVI,avi,ASF,asf}"]
puts "Video files: #{ video_files.length }"
puts "Begin import? (y/n):"
unless ::STDIN.gets.chomp =~ /^y/i
  exit
end

per_slice = 4
video_files.each_slice(per_slice).with_index do |list, index|
  puts "#{ index + 1 } / #{ video_files.length / per_slice }"

  threads = []
  list.each do |file|
    threads << Thread.new do
      command = "ffprobe -v quiet -print_format json -show_format -show_streams #{ Shellwords.escape file }"
      output = `#{ command }`
      json_output = JSON.parse output

      unless json_output['streams']
        logger.log file, 'could not parse file streams'
        next
      end

      video_stream = json_output['streams'].select { |stream| stream['codec_type'] == 'video'}.first
      audio_stream = json_output['streams'].select { |stream| stream['codec_type'] == 'audio'}.first

      unless video_stream
        logger.log file, 'could not find video stream'
        next
      end

      unless audio_stream
        logger.log file, 'could not find audio stream'
      end

      duration = video_stream['duration'].to_i

      if duration < DESIRED_SUBJECT_LENGTH
        logger.log file, 'file duration too short'
        next
      end

      video_codec = video_stream['codec_name']
      width = video_stream['width']
      height = video_stream['height']
      pix_fmt = video_stream['pix_fmt']
      s3_location = File.join config['s3_bucket_and_prefix'], file.gsub(config['input_path'], '')

      audio_codec = audio_stream ? audio_stream['codec_name'] : nil

      groups = mysql.with do |conn|
        conn.query("select bson_id, site_name from groups_manifest")
      end

      unless groups.count > 0
        logger.log file, "cannot determine subject group"
        next
      end

      group = groups.select { |group| file.include? group['site_name'] }.first

      pointer = 0
      while pointer < duration
        bson_id = BSON::ObjectId.new.to_s
        mysql.with do |conn|
          conn.query <<-SQL
            insert into subjects_manifest
              (bson_id, group_bson_id, file_location, duration, start_time, video_codec, audio_codec, width, height, pix_fmt)
            values (
              '#{ bson_id }',
              '#{ group['bson_id'] }',
              '#{ s3_location }',
              #{ DESIRED_SUBJECT_LENGTH },
              #{ pointer },
              '#{ video_codec }',
              '#{ audio_codec }',
              #{ width },
              #{ height },
              '#{ pix_fmt }'
            )
          SQL
        end

        pointer += DESIRED_SUBJECT_LENGTH
      end
    end
  end
  threads.each(&:join)
end
