require 'modern_times'
require 'shoulda'
require 'test/unit'
require 'fileutils'
require 'erb'

# NOTE: This test requires a running ActiveMQ server

module HashTest
  def self.create_obj(i)
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

  def self.parse_obj(obj)
    obj['answer']
  end

  def self.request(obj)
    {
        'answer' => obj['bar']['message']
    }
  end
end

module RubyTest

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

  def self.request(obj)
    return MyClass.new(obj.i+10)
  end
end

module StringTest
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

  def self.request(str)
    if str =~ /^Message (\d+)$/
      "Returning #{$1}"
    else
      raise "Unknown message: #{str}"
    end
  end
end

class DefaultWorker
  include ModernTimes::JMS::RequestWorker
  response :marshal => :yaml, :time_to_live => 10000

  def request(obj)
    options[:tester].request(obj)
  end
end

class SleepWorker
  include ModernTimes::JMS::RequestWorker
  response :marshal => :string, :time_to_live => 10000

  def request(i)
    sleep i.to_i
    return i
  end
end

class JMSRequestorTest < Test::Unit::TestCase

  @@server = JMX.simple_server
  @@client = JMX.connect

  context 'jms request' do
    setup do
      config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), 'jms.yml'))).result(binding))
      ModernTimes::JMS::Connection.init(config)
    end

    teardown do
    end

    {
      :bson   => HashTest,
      :json   => HashTest,
      :ruby   => RubyTest,
      :string => StringTest,
      :yaml   => HashTest
    }.each do |marshal, tester|

      context "marshaling with #{marshal}" do
        setup do
          @domain = "Uniquize_#{marshal}"
          @manager = ModernTimes::Manager.new(:domain => @domain)
        end

        teardown do
          if @manager
            @manager.stop
            @manager.join
          end
        end

        should "reply correctly with multiple threads" do
          DefaultWorker.response(:marshal => marshal, :time_to_live => 10000)
          @manager.add(DefaultWorker, 10, :tester => tester)

          sleep 1

          publisher = ModernTimes::JMS::Publisher.new(:queue_name => 'Default', :marshal => marshal, :response => true)
          threads = []
          start = Time.now
          (0..9).each do |i|
            threads << Thread.new(i) do |i|
              start = i*10
              range = start..(start+9)
              range.each do |x|
                obj = tester.create_obj(x)
                handle = publisher.publish(obj)
                reply_obj = handle.read_response(2)
                val = tester.parse_obj(reply_obj)
                assert x == val, "#{x} does not equal #{val}"
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
        @publisher = ModernTimes::JMS::Publisher.new(:queue_name => 'Sleep', :marshal => :string, :response => true)
      end

      teardown do
        if @manager
          @manager.stop
          @manager.join
        end
      end

      should "work correctly if request is complete before the timeout" do
        [[1,0,2,0.8,1.2], [2,1,3,1.8,2.2], [1,2,3,0.8,1.2], [3,1,2,2.8,3.2]].each do |info|
          work_sleep_time, publish_sleep_time, timeout_time, min_time, max_time = info
          threads      = []
          start_time   = Time.now
          (0..9).each do |i|
            threads << Thread.new(i) do |i|
              handle = @publisher.publish(work_sleep_time)
              sleep publish_sleep_time
              if work_sleep_time < timeout_time
                response = handle.read_response(timeout_time).to_i
                assert work_sleep_time == response, "#{work_sleep_time} does not equal #{response}"
              else
                assert handle.read_response(timeout_time).nil?
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
          all_times << total_time if work_sleep_time > publish_sleep_time && work_sleep_time < timeout_time
          all_times.each do |time_val|
            assert min_time < time_val, "#{time_val} is not between #{min_time} and #{max_time}"
            assert max_time > time_val, "#{time_val} is not between #{min_time} and #{max_time}"
          end
        end
      end
    end

    context 'dummy requesting' do
      setup do
        @tester = RubyTest
        workers = [
          DefaultWorker.new(:tester => @tester)
        ]
        ModernTimes::JMS::Publisher.setup_dummy_publishing(workers)
      end

      teardown do
        ModernTimes::JMS::Publisher.clear_dummy_publishing
      end

      should "directly call applicable workers" do
        x=9999
        obj = @tester.create_obj(x)
        publisher = ModernTimes::JMS::Publisher.new(:queue_name => 'Default', :marshal => :ruby, :response => true)
        handle = publisher.publish(obj)
        reply_obj = handle.read_response(2)
        val = @tester.parse_obj(reply_obj)
        assert x == val, "#{x} does not equal #{val}"
      end
    end
  end
end
