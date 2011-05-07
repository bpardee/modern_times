require 'modern_times'
require 'shoulda'
require 'test/unit'
require 'fileutils'
require 'erb'

# NOTE: This test requires a running ActiveMQ server

module HashTest
  module ModuleMethods
    def create_obj(i)
      {
          'foo' => 1,
          'bar' => {
              'message' => i,
              'dummy'   => "Message #{i}"
          },
          # Only YAML will maintain symbols
          :zulu => :rugger
      }
    end

    def parse_obj(obj)
      obj['answer']
    end
  end

  def self.included(base)
    base.extend(ModuleMethods)
  end

  def request(obj)
    {
        'answer' => obj['bar']['message']
    }
  end
end

module BSONTest
  extend ModernTimes::MarshalStrategy::BSON
  include HashTest
end

module JSONTest
  extend ModernTimes::MarshalStrategy::JSON
  include HashTest
end

module RubyTest
  extend ModernTimes::MarshalStrategy::Ruby

  class MyClass
    attr_reader :i
    def initialize(i)
      @i = i
    end
  end

  def self.create_obj(i)
    MyClass.new(i)
  end

  def self.parse_obj(obj)
    obj.i-10
  end

  def request(obj)
    return MyClass.new(obj.i+10)
  end
end

module StringTest
  extend ModernTimes::MarshalStrategy::String

  def self.create_obj(i)
    "Message #{i}"
  end

  def self.parse_obj(obj)
    if obj =~ /^Returning (\d+)$/
      $1.to_i
    else
      raise "Unknown message: #{obj}"
    end
  end

  def request(str)
    if str =~ /^Message (\d+)$/
      "Returning #{$1}"
    else
      raise "Unknown message: #{str}"
    end
  end
end

class DefaultWorker
  include ModernTimes::JMS::RequestWorker
end

class SleepWorker
  include ModernTimes::JMS::RequestWorker
  marshal :string

  def request(i)
    sleep i.to_i
    return i
  end
end

class JMSRequestorTest < Test::Unit::TestCase

  @@server = JMX.simple_server
  @@client = JMX.connect

  context 'jms' do
    setup do
      config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), 'jms.yml'))).result(binding))
      ModernTimes::JMS::Connection.init(config)
    end

    teardown do
    end

    #[BSONTest, JSONTest, RubyTest, StringTest].each do |marshal_module|
    [BSONTest, JSONTest, StringTest].each do |marshal_module|
      marshal_module.name =~ /(.*)Test/
      marshal_type = $1

      context "marshaling with #{marshal_type}" do
        setup do
          @domain = "Uniquize_#{marshal_module.name}"
          @manager = ModernTimes::Manager.new(:domain => @domain)
        end

        teardown do
          if @manager
            @manager.stop
            @manager.join
          end
        end

        should "reply correctly with multiple threads" do
          DefaultWorker.send(:include, marshal_module)
          DefaultWorker.send(:marshal, marshal_module)
          @manager.add(DefaultWorker, 10)

          sleep 1

          publisher = ModernTimes::JMS::Publisher.new(:queue_name => 'Default', :marshal => marshal_module)
          threads = []
          start = Time.now
          (0..9).each do |i|
            threads << Thread.new(i) do |i|
              start = i*10
              range = start..(start+9)
              range.each do |x|
                obj = marshal_module.create_obj(x)
                handle = publisher.publish(obj, 2)
                val = marshal_module.parse_obj(handle.read_response)
                assert x == val, "#{i} does not equal #{val}"
              end
            end
          end
          threads.each {|t| t.join}
        end
      end
    end

    context 'timed requesting' do
      setup do
        @domain = "TimedModernTimes"
        @manager = ModernTimes::Manager.new(:domain => @domain)
        @manager.add(SleepWorker, 10)
        sleep 1
        @requestor = ModernTimes::JMS::Publisher.new(:queue_name => 'Sleep', :marshal => :string)
      end

      teardown do
        if @manager
          @manager.stop
          @manager.join
        end
      end

      should "work correctly if request is complete before the timeout" do
        [[1,0,2,0.8,1.2], [2,1,3,1.6,2.4], [1,2,3,0,8,1.2], [3,1,2,2.8,3.4]].each do |info|
          work_sleep_time, publish_sleep_time, timeout_time, min_time, max_time = info
          threads      = []
          start_time   = Time.now
          (0..9).each do |i|
            threads << Thread.new(i) do |i|
              handle = @requestor.request(work_sleep_time, timeout_time)
              sleep publish_sleep_time
              if work_sleep_time < timeout_time
                response = handle.read_response.to_i
                assert work_sleep_time == response, "#{work_sleep_time} does not equal #{response}"
              else
                e = assert_raises Timeout::Error do
                  response = handle.read_response.to_i
                end
                actual_time = Time.now - start_time
                assert timeout_time-0.1 < actual_time, "Bad timeout #{actual_time}"
                assert timeout_time+0.3 > actual_time, "Bad timeout #{actual_time}"

                # Give the requests time to complete
                sleep work_sleep_time - timeout_time + 1
              end
            end
          end
          threads.each {|t| t.join}
          total_time = Time.now - start_time
          bean = @@client[ModernTimes.supervisor_mbean_object_name(@domain, 'Sleep')]
          bean_avg = bean.average_response_time
          bean_min = bean.min_response_time
          bean_max = bean.max_response_time
          puts "total=#{total_time} avg=#{bean_avg} min=#{bean_min} max=#{bean_max}"
          all_times = [bean_avg, bean_min, bean_max]
          all_times << total_time if work_sleep_time < timeout_time
          all_times.each do |time_val|
            assert min_time < time_val, "#{time_val} is not between #{min_time} and #{max_time}"
            assert max_time > time_val, "#{time_val} is not between #{min_time} and #{max_time}"
          end
        end
      end
    end

#    context 'dummy requesting' do
#      setup do
#        workers = [
#          DefaultWorker,
#          Dummy::DefaultWorker,
#          SpecifiedQueueWorker,
#          SpecifiedQueue2Worker,
#          SpecifiedTopicWorker,
#          SpecifiedTopic2Worker,
#        ]
#        workers.each do |worker_klass|
#          worker_klass.send(:include, RubyTest)
#        end
#        ModernTimes::JMS::Publisher.setup_dummy_publishing(workers)
#      end
#
#      teardown do
#        ModernTimes::JMS::Publisher.clear_dummy_publishing
#      end
#
#      should "directly call applicable workers" do
#        publish(RubyTest, 100..199, :queue_name => 'Default')
#        publish(RubyTest, 200..299, :queue_name => 'Dummy_Default')
#        publish(RubyTest, 300..499, :queue_name => 'MyQueueName')
#        publish(RubyTest, 500..599, :virtual_topic_name => 'MyTopicName')
#
#        # DefaultWorker should have 5 instances running with each worker handling between 10-30 messages in the range 100.199
#        assert_worker(nil, DefaultWorker,         nil, 1, 100..199, 100, 100, 1)
#        assert_worker(nil, Dummy::DefaultWorker,  nil, 1, 200..299, 100, 100, 1)
#        assert_worker(nil, SpecifiedQueueWorker,  nil, 1, 300..499, 200, 200, 1)
#        assert_worker(nil, SpecifiedQueue2Worker, nil, 1, 300..499, 200, 200, 1)
#        assert_worker(nil, SpecifiedTopicWorker,  nil, 1, 500..599, 100, 100, 1)
#        assert_worker(nil, SpecifiedTopic2Worker, nil, 1, 500..599, 100, 100, 1)
#      end
#    end
  end
end
