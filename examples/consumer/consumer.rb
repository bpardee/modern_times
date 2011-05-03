# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'erb'
require 'modern_times'
require 'yaml'

if ARGV.size < 2
  $stderr.puts "Usage: {$0} <message> <id>"
end

#ModernTimes::JMS::Publisher.setup_dummy_publishing([])
#ModernTimes::JMS::Consumer.setup_dummy_receiving

config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), '..', 'jms.yml'))).result(binding))
ModernTimes::JMS::Connection.init(config)
publisher = ModernTimes::JMS::Publisher.new(:queue_name => 'Foo', :marshal => :string)
consumer = ModernTimes::JMS::Consumer.new(:queue_name => 'Foo', :marshal => :string)

publisher.publish(ARGV[0], :jms_correlation_id => ARGV[1])
msg = consumer.receive(:jms_correlation_id => ARGV[1], :timeout => 30000)
#msg = consumer.receive(:timeout => 1000)
puts "msg=#{msg}"
