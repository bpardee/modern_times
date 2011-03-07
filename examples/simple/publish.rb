# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'modern_times'
require 'yaml'
require 'bar_worker'
require 'baz_worker'

config = YAML.load_file('hornetq.yml')
ModernTimes::HornetQ::Client.init(config['client'])
count = (ARGV[1] || 1).to_i
(1..count).each do |i|
  msg = "Message ##{i}"
  puts "Pulishing to #{ARGV[0]} message: #{msg}"
  ModernTimes::HornetQ::Client.publish(ARGV[0], msg)
  sleep 0.2
end
