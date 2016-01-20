require 'json'

response = JSON.parse `aws ec2 describe-instances --filter Name=tag:Name,Values=chimps-slave Name=instance-state-name,Values=running`

instances = response['Reservations'][0]['Instances']
dns_entries = instances.collect { |instance| instance['PublicDnsName'] }

dns_entries.each do |destination|
  `scp -i ~/.ssh/zooniverse_1.pem -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /home/zooniverse/project-data/chimp-zoo/consumer.rb ec2-user@#{ destination }:consumer.rb`
end

puts "Deployed."
