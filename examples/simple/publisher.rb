# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'modern_times'
require 'bar_worker'
require 'baz_worker'
require '../setup_adapter'

if ARGV.size < 2
  $stderr.puts "Usage: {$0} <bar-publish-count> <baz-publish-count> [sleep-time]"
end

bar_count = ARGV[0].to_i
baz_count = ARGV[1].to_i
sleep_time = (ARGV[2] || 0.2).to_f

bar_publisher = ModernTimes::Publisher.new(:queue_name => 'Bar', :marshal => :bson)
baz_publisher = ModernTimes::Publisher.new(:queue_name => 'Baz', :marshal => :string)

(1..bar_count).each do |i|
  obj = {'message' => i}
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
class Publisher
  include ModernTimes::Publisher

  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 5

  def perform(obj)
    puts "#{self}: Received #{obj.inspect} at #{Time.now}"
    sleep config.sleep_time
  end
end
include Rumx::Bean

bean_attr_reader   :greeting,           :string,  'My greeting'
bean_reader        :goodbye,            :string,  'My goodbye'
bean_attr_accessor :my_accessor,        :integer, 'My integer accessor'
bean_attr_writer   :my_writer,          :float,   'My float writer'
bean_reader        :readable_my_writer, :float,   'My secret access to the write-only attribute my_writer'

bean_operation     :my_operation,       :string,  'My operation', [
    [ :arg_int,    :integer, 'An int argument'   ],
    [ :arg_float,  :float,   'A float argument'  ],
    [ :arg_string, :string,  'A string argument' ]
]

def initialize
  @greeting    = 'Hello, Rumx'
  @my_accessor = 4
  @my_writer   = 10.78
end

def goodbye
  'Goodbye, Rumx (hic)'
end

def readable_my_writer
  @my_writer
end

def my_operation(arg_int, arg_float, arg_string)
  "arg_int class=#{arg_int.class} value=#{arg_int} arg_float class=#{arg_float.class} value=#{arg_float} arg_string class=#{arg_string.class} value=#{arg_string}"
end
