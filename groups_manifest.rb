require 'bson'
require 'mysql2'
require 'yaml'

$adjs = [
  "autumn", "hidden", "bitter", "misty", "silent", "empty", "dry", "dark",
  "summer", "icy", "delicate", "quiet", "white", "cool", "spring", "winter",
  "patient", "twilight", "dawn", "crimson", "wispy", "weathered", "blue",
  "billowing", "broken", "cold", "damp", "falling", "frosty", "green",
  "long", "late", "lingering", "bold", "little", "morning", "muddy", "old",
  "red", "rough", "still", "small", "sparkling", "throbbing", "shy",
  "wandering", "withered", "wild", "black", "young", "holy", "solitary",
  "fragrant", "aged", "snowy", "proud", "floral", "restless", "divine",
  "polished", "ancient", "purple", "lively", "nameless"
]
$nouns = [
  "waterfall", "river", "breeze", "moon", "rain", "wind", "sea", "morning",
  "snow", "lake", "sunset", "pine", "shadow", "leaf", "dawn", "glitter",
  "forest", "hill", "cloud", "meadow", "sun", "glade", "bird", "brook",
  "butterfly", "bush", "dew", "dust", "field", "fire", "flower", "firefly",
  "feather", "grass", "haze", "mountain", "night", "pond", "darkness",
  "snowflake", "silence", "sound", "sky", "shape", "surf", "thunder",
  "violet", "water", "wildflower", "wave", "water", "resonance", "sun",
  "wood", "dream", "cherry", "tree", "fog", "frost", "voice", "paper",
  "frog", "smoke", "star"
]

def generate_fake_name
  "#{ $adjs.sample }-#{ $nouns.sample }"
end

config = YAML.load_file File.join(Dir.pwd, 'config.yml')
mysql = Mysql2::Client.new(
  host: config['mysql']['hostname'],
  username: config['mysql']['username'],
  password: config['mysql']['password'],
  database: config['mysql']['database']
)

groups = Dir["#{ config['input_path'] }/*"].select { |path|
  # This is brittle.
  if !File.directory? path
    false
  elsif (%w($) & path.chars).length > 0
    false
  else
    true
  end
}

groups.each.with_index do |group, index|
  site_name = File.split(group).last

  escaped_name = mysql.escape site_name
  result = mysql.query("select * from groups_manifest where site_name='#{ escaped_name }'")
  if result.count == 0
    id = BSON::ObjectId.new.to_s

    mysql.query <<-SQL
      insert into groups_manifest
        (bson_id, site_name, fake_name, drive)
      values (
        '#{ id }',
        '#{ escaped_name }',
        '#{ generate_fake_name }',
        4
      )
    SQL
  end
end

puts "Done."
