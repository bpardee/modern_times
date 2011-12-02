# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'

require 'rubygems'
require 'modern_times'

class Publisher
  include Rumx::Bean

  bean_attr_accessor :bar_count, :integer, 'Number of Bar messages sent'
  bean_attr_accessor :baz_count, :integer, 'Number of Baz messages sent'

  bean_operation :send_bar, :void, 'Send messages to the Bar worker', [
      [ :count,      :integer, 'Count of messages',                     10                 ],
      [ :message,    :string,  'String portion of the message to send', 'Message for Bar'  ],
      [ :sleep_time, :float,   'Time to sleep between messages',        0.2                ]
  ]

  bean_operation :send_baz, :void, 'Send messages to the Baz worker', [
      [ :count,      :integer, 'Count of messages',                     5                  ],
      [ :message,    :string,  'String portion of the message to send', 'Message for Baz'  ],
      [ :sleep_time, :float,   'Time to sleep between messages',        0.5                ]
  ]

  @@bar_publisher = ModernTimes::Publisher.new(:queue_name => 'Bar', :marshal => :bson)
  @@baz_publisher = ModernTimes::Publisher.new(:queue_name => 'Baz', :marshal => :string)

  def initialize
    @bar_count = 0
    @baz_count = 0
  end

  def send_bar(count, message, sleep_time)
    count.times do
      @bar_count += 1
      obj = {'count' => @bar_count, 'message' => message}
      puts "Publishing to Bar object: #{obj.inspect}"
      @@bar_publisher.publish(obj)
      sleep sleep_time
    end
  end

  def send_baz(count, message, sleep_time)
    count.times do
      @baz_count += 1
      obj = "#{@baz_count}: #{message}"
      puts "Publishing to Baz object: #{obj}"
      @@baz_publisher.publish(obj)
      sleep sleep_time
    end
  end
end
