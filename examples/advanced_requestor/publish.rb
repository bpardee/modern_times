# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'erb'
require 'modern_times'
require 'yaml'

if ARGV.size < 1
  $stderr.puts "Usage: {$0} <string> [<timeout>] [<sleep>]"
  exit 1
end

string     =  ARGV[0]
timeout    = (ARGV[1] || 4).to_f
sleep_time = (ARGV[2] || 2).to_f

config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), '..', 'jms.yml'))).result(binding))
ModernTimes::JMS::Connection.init(config)
publisher = ModernTimes::JMS::Publisher.new(:virtual_topic_name => 'test_string', :response => true, :marshal => :string)
handle = publisher.publish(string)
sleep sleep_time

handle.read_response(timeout) do |response|
  response.on_message 'CharCount' do |hash|
    puts "CharCount returned #{hash.inspect}"
  end
  response.on_message 'Length', 'Reverse' do |val|
    puts "#{response.name} returned #{val}"
  end
  response.on_message 'ExceptionRaiser' do |val|
    puts "#{response.name} didn't raise an exception, returned \"#{val}\""
  end
  response.on_message do |val|
    puts "#{response.name} caught by default handler and returned #{val} but if it timed out we wouldn't know since it wasn't explicitly specified"
  end
  response.on_timeout 'Reverse' do
    puts "Reverse has it's own timeout handler"
  end
  response.on_timeout do
    puts "#{response.name} did not respond in time"
  end
  response.on_remote_exception 'ExceptionRaiser' do |e|
    puts "It figures that ExceptionRaiser would raise an exception: #{e.message}"
  end
  response.on_remote_exception do |e|
    puts "#{response.name} raised an exception: #{e.message}"
  end
end
