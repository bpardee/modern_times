# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'erb'
require 'modern_times'
require 'yaml'
require 'reverse_echo_worker'

if ARGV.size < 1
  $stderr.puts "Usage: {$0} <reverse-echo-string> [<timeout>] [<sleep-time>] [<simultaneous-count>]"
  exit 1
end

$echo_string =  ARGV[0]
$timeout     = (ARGV[1] || 4).to_f
$sleep_time  = (ARGV[2] || 2).to_i
$sim_count   = (ARGV[3] || 1).to_i

config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), '..', 'jms.yml'))).result(binding))
ModernTimes::JMS::Connection.init(config)
$requestor = ModernTimes::JMSRequestor::Requestor.new(:queue_name => ReverseEchoWorker.default_name, :marshal => :string)

def make_request(ident='')
  puts "#{ident}Making request at #{Time.now.to_f}"
  handle = $requestor.request("#{ident}#{$echo_string}", $timeout)
  # Here's where we'd go off and do other work
  sleep $sleep_time
  puts "#{ident}Finished sleeping at #{Time.now.to_f}"
  response = handle.read_response
  puts "#{ident}Received at #{Time.now.to_f}: #{response}"
rescue Exception => e
  puts "#{ident}Exception: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
end

if $sim_count == 1
  make_request
else
  threads = []
  (1..$sim_count).each do |i|
    threads << Thread.new(i) do |i|
      make_request("Thread ##{i}: ")
    end
  end
  threads.each {|t| t.join}
end
