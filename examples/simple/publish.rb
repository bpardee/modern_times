# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'modern_times'
require 'yaml'
require 'bar_worker'
require 'baz_worker'

if ARGV.size < 2
  $stderr.puts "Usage: {$0} <bar-publish-count> <baz-publish-count> [sleep-time]"
end

bar_count = ARGV[0].to_i
baz_count = ARGV[1].to_i
sleep_time = (ARGV[2] || 0.2).to_f

config = YAML.load_file('hornetq.yml')
ModernTimes::HornetQ::Client.init(config['client'])
bar_publisher = ModernTimes::HornetQ::Publisher.new(BarWorker.address_name)
baz_publisher = ModernTimes::HornetQ::Publisher.new(BazWorker.address_name, :marshal => :string)

(1..bar_count).each do |i|
  obj = {:message => i}
  puts "Publishing to Bar object: #{obj.inspect}"
  bar_publisher.publish(obj)
  sleep sleep_time
end

(1..baz_count).each do |i|
  obj = "Message ##{i}"
  puts "Publishing to Baz object: #{obj}"
  baz_publisher.publish(obj)
  sleep sleep_time
end
