require 'aws'
require 'bson'
require 'json'
require 'mysql2'
require 'open3'
require 'shellwords'
require 'yaml'

unless ARGV[0]
  puts "Must provide at least one site to generate a manifest for."
  exit
end

config = YAML.load_file File.join Dir.pwd, 'config.yml'
mysql = Mysql2::Client.new(
  host: config['mysql']['hostname'],
  username: config['mysql']['username'],
  password: config['mysql']['password'],
  database: config['mysql']['database']
)

sites = ARGV
sites.each do |site|
  puts "Creating manifest for #{ site }"

  subjects_manifest_file = File.open "/data/#{ site }_subjects.txt", 'w'

  results = mysql.query <<-SQL
    SELECT s.*, g.site_name, g.fake_name, g.drive
    FROM subjects_manifest s
    INNER JOIN groups_manifest g ON s.group_bson_id = g.bson_id
    WHERE g.site_name = '#{ site }'
  SQL

  puts "Found #{ results.count } records for #{ site }."
  counter = 0
  results.each do |row|
    counter += 1

    if counter == 1
      groups_manifest_file = File.open "/data/#{ site }_group.txt", 'w'
      group = {
        id: row['group_bson_id'],
        name: row['fake_name'],
        metadata: {
          site: row['site_name'],
          fake_name: row['fake_name'] 
        }
      }
      groups_manifest_file.puts JSON.dump(group)
    end

    bson_id = row['bson_id']

    # the previews part here is silly
    subject = {
      id: bson_id,
      group_id: row['group_bson_id'],
      location: {
        standard: {
          mp4: "http://www.chimpandsee.org/subjects/#{ bson_id }/#{ bson_id }.mp4",
          webm: "http://www.chimpandsee.org/subjects/#{ bson_id }/#{ bson_id }.webm",
        },
        previews: [
          [
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_0.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_2.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_4.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_5.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_7.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_9.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_11.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_13.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_14.jpg"
          ],
          [
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_0.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_1.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_3.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_6.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_8.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_10.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_12.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_14.jpg",
            "http://www.chimpandsee.org/subjects/#{ bson_id }/previews/#{ bson_id }_15.jpg"
          ]
        ]
      },
      metadata: {
        file: row['file_location'].gsub('zooniverse-data/chimps/', ''),
        duration: row['duration'].to_i,
        start_time: row['start_time']
      }
    }

    subjects_manifest_file.print(JSON.dump(subject) + "\n")
  end


end




