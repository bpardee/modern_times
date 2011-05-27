require 'modern_times'
require 'shoulda'
require 'test/unit'
require 'fileutils'
require 'erb'

# NOTE: This test requires a running ActiveMQ server

class ExceptionWorker
  include ModernTimes::JMS::Worker
  def perform(obj)
    puts "#{name} received #{obj} but raising exception"
    raise 'foobar'
  end

  def log_backtrace(e)
  end
end

class ExceptionRequestWorker
  include ModernTimes::JMS::RequestWorker

  def request(obj)
    puts "#{name} received #{obj} but raising exception"
    raise 'foobar'
  end

  def log_backtrace(e)
  end
end

# This will read from the queue that ExceptionWorker fails to
class ExceptionFailWorker
  include ModernTimes::JMS::Worker

  @@my_hash = {}

  def self.my_obj(name)
    @@my_hash[name]
  end

  def perform(obj)
    puts "#{name} received #{obj}"
    @@my_hash[name] = obj
  end
end

class JMSFailTest < Test::Unit::TestCase

  def assert_fail_queue(queue_name, fail_queue_name, value, is_fail_queue_expected)
    # Publish to Exception that will throw exception which will put on ExceptionFail queue
    publisher = ModernTimes::JMS::Publisher.new(:queue_name => queue_name, :marshal => :string)
    puts "Publishing #{value} to #{queue_name}"
    publisher.publish(value)
    sleep 1
    expected_value = (is_fail_queue_expected ? value : nil)
    assert_equal expected_value, ExceptionFailWorker.my_obj(fail_queue_name)
  end

  context 'jms' do
    setup do
      config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), 'jms.yml'))).result(binding))
      ModernTimes::JMS::Connection.init(config)
    end

    teardown do
    end

    context "worker with exception" do
      setup do
        @manager = ModernTimes::Manager.new

        # Should receive message on the fail worker when using with default names
        @manager.add(ExceptionWorker, 1)
        @manager.add(ExceptionFailWorker, 1)

        # Should receive message on the fail worker when using specified names
        name = 'ExceptionNameSpecified'
        @manager.add(ExceptionWorker, 1, :name => name)
        @manager.add(ExceptionFailWorker, 1, :name => "#{name}Fail")

        # Should receive message on the fail worker when using specified names and fail_queue set true
        name = 'ExceptionFailQueueTrue'
        @manager.add(ExceptionWorker, 1, :name => name, :fail_queue => true)
        @manager.add(ExceptionFailWorker, 1, :name => "#{name}Fail")

        # Should NOT receive message on the fail worker when using specified names and fail_queue set false
        name = 'ExceptionFailQueueFalse'
        @manager.add(ExceptionWorker, 1, :name => name, :fail_queue => false)
        @manager.add(ExceptionFailWorker, 1, :name => "#{name}Fail")

        # Should NOT receive message on the fail worker when using specified names and fail_queue set false
        name = 'ExceptionFailQueueSpecified'
        fail_queue = 'MyFailQueue'
        @manager.add(ExceptionWorker, 1, :name => name, :fail_queue => fail_queue)
        @manager.add(ExceptionFailWorker, 1, :name => fail_queue)

        # Should NOT receive message on the fail worker
        name = 'ExceptionRequest'
        @manager.add(ExceptionRequestWorker, 1)
        @manager.add(ExceptionFailWorker, 1, :name => "#{name}Fail")

        # Should NOT receive message on the fail worker when using specified names
        name = 'ExceptionRequestNameSpecified'
        @manager.add(ExceptionRequestWorker, 1, :name => name)
        @manager.add(ExceptionFailWorker, 1, :name => "#{name}Fail")

        # Should receive message on the fail worker when using specified names and fail_queue set true
        name = 'ExceptionRequestFailQueueTrue'
        @manager.add(ExceptionRequestWorker, 1, :name => name, :fail_queue => true)
        @manager.add(ExceptionFailWorker, 1, :name => "#{name}Fail")

        # Should NOT receive message on the fail worker when using specified names and fail_queue set false
        name = 'ExceptionRequestFailQueueFalse'
        @manager.add(ExceptionRequestWorker, 1, :name => name, :fail_queue => false)
        @manager.add(ExceptionFailWorker, 1, :name => "#{name}Fail")

        # Should NOT receive message on the fail worker when using specified names and fail_queue set false
        name = 'ExceptionRequestFailQueueSpecified'
        fail_queue = 'MyRequestFailQueue'
        @manager.add(ExceptionRequestWorker, 1, :name => name, :fail_queue => fail_queue)
        @manager.add(ExceptionFailWorker, 1, :name => fail_queue)

        sleep 1
      end

      teardown do
        if @manager
          @manager.stop
          @manager.join
        end
      end

      should "write fail messages to a fail queue" do
        assert_fail_queue('Exception',                          'ExceptionFail',                      'value0', true)
        assert_fail_queue('ExceptionNameSpecified',             'ExceptionNameSpecifiedFail',         'value1', true)
        assert_fail_queue('ExceptionFailQueueTrue',             'ExceptionFailQueueTrueFail',         'value2', true)
        assert_fail_queue('ExceptionFailQueueFalse',            'ExceptionFailQueueFalseFail',        'value3', false)
        assert_fail_queue('ExceptionFailQueueSpecified',        'MyFailQueue',                        'value4', true)

        assert_fail_queue('ExceptionRequest',                   'ExceptionRequestFail',               'value5', false)
        assert_fail_queue('ExceptionRequestNameSpecified',      'ExceptionRequestNameSpecifiedFail',  'value6', false)
        assert_fail_queue('ExceptionRequestFailQueueTrue',      'ExceptionRequestFailQueueTrueFail',  'value7', true)
        assert_fail_queue('ExceptionRequestFailQueueFalse',     'ExceptionRequestFailQueueFalseFail', 'value8', false)
        assert_fail_queue('ExceptionRequestFailQueueSpecified', 'MyRequestFailQueue',                 'value9', true)
      end
    end
  end
end
