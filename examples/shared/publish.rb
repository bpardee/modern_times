# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'erb'
require 'modern_times'
require 'yaml'

if ARGV.size < 2
  $stderr.puts "Usage: {$0} <s1-publish-count> <s2-publish-count> [sleep-time]"
end

s1_count = ARGV[0].to_i
s2_count = ARGV[1].to_i
sleep_time = (ARGV[2] || 0.2).to_f

config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), '..', 'jms.yml'))).result(binding))
ModernTimes::JMS::Connection.init(config)
s1_publisher = ModernTimes::JMS::Publisher.new(:queue_name => 'S1', :marshal => :bson)
s2_publisher = ModernTimes::JMS::Publisher.new(:queue_name => 'S2', :marshal => :string)

(1..s1_count).each do |i|
  obj = {'message' => i}
  puts "Publishing to Bar object: #{obj.inspect}"
  s1_publisher.publish(obj)
  sleep sleep_time
end

(1..s2_count).each do |i|
  obj = "Message ##{i}"
  puts "Publishing to Baz object: #{obj}"
  s2_publisher.publish(obj)
  sleep sleep_time
end
