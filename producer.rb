require 'aws-sdk'
require 'base64'
require 'mysql2'
require 'open3'
require 'shellwords'
require 'yaml'

unless ARGV[0]
  puts "Must provide at least one site to work on."
  exit
end

config = YAML.load_file File.join Dir.pwd, 'config.yml'

Aws.config.update({
  region: config['aws']['region'],
  credentials: Aws::Credentials.new(config['aws']['key'], config['aws']['secret'])
})

sqs = Aws::SQS::Client.new
mysql = Mysql2::Client.new(
  host: config['mysql']['hostname'],
  username: config['mysql']['username'],
  password: config['mysql']['password'],
  database: config['mysql']['database']
)

sites = ARGV
sites.each do |site|
  site_escaped = mysql.escape(site)
  results = mysql.query("SELECT s.* FROM subjects_manifest s INNER JOIN groups_manifest g ON s.group_bson_id = g.bson_id WHERE g.site_name = '#{site_escaped}'", stream: true)
  results.each do |result|
    sqs.send_message(
      queue_url: 'https://sqs.us-east-1.amazonaws.com/927935712646/chimps-data-processing',
      message_body: Base64.encode64(result.to_json)
    )
  end
end
