require 'modern_times'
require 'shoulda'
require 'test/unit'
require 'fileutils'
require 'erb'

# NOTE: This test requires a running ActiveMQ server

module WorkerHelper
  @@workers = {}
  @@mutex   = Mutex.new
  def initialize(opts={})
    super
    @tester = opts[:tester]
    @@mutex.synchronize do
      @@workers[self.name] ||= []
      @@workers[self.name] << self
    end
    @hash = Hash.new(0)
  end

  def perform(obj)
    add_message(@tester.translate(obj))
  end

  def self.workers(names)
    workers = []
    names.each {|name| workers += @@workers[name]}
    workers
  end

  def self.reset_workers
    @@workers = {}
  end

  def add_message(i)
    @hash[i] += 1
  end

  def call_count
    puts "hash=#{@hash.inspect}"
    @hash.values.reduce(:+)
  end

  def messages
    @hash.keys
  end
end

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

  def self.translate(obj)
    obj['bar']['message']
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

  def self.translate(obj)
    obj.i
  end
end

module StringTest
  def self.create_obj(i)
    "Message #{i}"
  end

  def self.translate(str)
    if str =~ /^Message (\d+)$/
      $1.to_i
    else
      raise "Unknown message: #{str}"
    end
  end
end

class DefaultWorker
  include ModernTimes::JMS::Worker
  include WorkerHelper
end

module Dummy
  class DefaultWorker
    include ModernTimes::JMS::Worker
    include WorkerHelper
  end
end

class SpecifiedQueueWorker
  include ModernTimes::JMS::Worker
  queue 'MyQueueName'
  include WorkerHelper
end

class SpecifiedQueue2Worker
  include ModernTimes::JMS::Worker
  queue 'MyQueueName'
  include WorkerHelper
end

class SpecifiedTopicWorker
  include ModernTimes::JMS::Worker
  virtual_topic 'MyTopicName'
  include WorkerHelper
end

class SpecifiedTopic2Worker
  include ModernTimes::JMS::Worker
  virtual_topic 'MyTopicName'
  include WorkerHelper
end

class JMSTest < Test::Unit::TestCase

  @@server = JMX.simple_server
  @@client = JMX.connect

  def publish(marshal, tester, range, options)
    publisher = ModernTimes::JMS::Publisher.new(options.merge(:marshal => marshal))
    puts "Publishing #{range} to #{publisher} via #{marshal}"
    range.each do |i|
      obj = tester.create_obj(i)
      publisher.publish(obj)
    end
  end
  
  def assert_worker(domain, names, worker_count, range, min, max, instance_count)
    puts "Checking #{names.inspect}"
    names = [names] unless names.kind_of?(Array)
    workers = WorkerHelper.workers(names)

    assert_equal worker_count, workers.size
    all_messages = []
    workers.each do |worker|
      msg_count = worker.call_count
      assert msg_count
      assert msg_count >= min, "#{msg_count} is not between #{min} and #{max}"
      assert msg_count <= max, "#{msg_count} is not between #{min} and #{max}"
      # Make sure no duplicate messages
      assert msg_count == worker.messages.size, "#{msg_count} is not == #{worker.messages.size}"
      all_messages.concat(worker.messages)
    end
    all_messages.sort!
    assert_equal all_messages, (range.to_a*instance_count).sort

    if domain
      total_count = 0
      names.each do |name|
        bean = @@client[ModernTimes.supervisor_mbean_object_name(domain, name)]
        bean.message_counts.each do |msg_count|
          total_count += msg_count
          assert msg_count >= min, "#{msg_count} is not between #{min} and #{max}"
          assert msg_count <= max, "#{msg_count} is not between #{min} and #{max}"
        end
      end
      assert_equal all_messages.size, total_count
    end
  end

  context 'jms' do
    setup do
      config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), 'jms.yml'))).result(binding))
      ModernTimes::JMS::Connection.init(config)
    end

    teardown do
    end

    {
      :bson => HashTest,
      :json => HashTest,
      :ruby => RubyTest,
      :string => StringTest,
      :yaml => HashTest
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

        should "operate on queues and topics" do
          WorkerHelper.reset_workers
          @manager.add(DefaultWorker, 3, :tester => tester)
          @manager.add(DefaultWorker, 2, :name => 'DefaultClone', :tester => tester)
          @manager.add(Dummy::DefaultWorker, 4, :tester => tester)
          @manager.add(SpecifiedQueueWorker, 3, :tester => tester)
          @manager.add(SpecifiedQueueWorker, 2, :name => 'SpecifiedQueueClone', :tester => tester)
          @manager.add(SpecifiedQueue2Worker, 2, :tester => tester)
          @manager.add(SpecifiedTopicWorker, 3, :tester => tester)
          @manager.add(SpecifiedTopicWorker, 2, :name => 'SpecifiedTopicClone', :tester => tester)
          @manager.add(SpecifiedTopic2Worker, 2, :tester => tester)

          sleep 1

          publish(marshal, tester, 100..199, :queue_name => 'Default')
          publish(marshal, tester, 200..299, :queue_name => 'DefaultClone')
          publish(marshal, tester, 300..399, :queue_name => 'Dummy_Default')
          publish(marshal, tester, 400..599, :queue_name => 'MyQueueName')
          publish(marshal, tester, 600..699, :virtual_topic_name => 'MyTopicName')

          # Let the workers do their thing
          sleep 5

          # DefaultWorker should have 5 instances running with each worker handling between 10-30 messages in the range 100.199
          assert_worker(@domain, 'Default',                                                    3, 100..199, 30, 36, 1)
          assert_worker(@domain, 'DefaultClone',                                               2, 200..299, 45, 55, 1)
          assert_worker(@domain, 'Dummy_Default',                                              4, 300..399, 20, 30, 1)
          assert_worker(@domain, ['SpecifiedQueue', 'SpecifiedQueueClone', 'SpecifiedQueue2'], 7, 400..599, 20, 40, 1)
          assert_worker(@domain, ['SpecifiedTopic', 'SpecifiedTopicClone'],                    5, 600..699, 30, 60, 2)
          assert_worker(@domain, 'SpecifiedTopic2',                                            2, 600..699, 35, 65, 1)
        end
      end
    end

    context 'dummy publishing' do
      setup do
        WorkerHelper.reset_workers
        workers = [
          DefaultWorker.new(:tester => RubyTest),
          DefaultWorker.new(:tester => RubyTest, :name => 'DefaultClone'),
          Dummy::DefaultWorker.new(:tester => RubyTest),
          SpecifiedQueueWorker.new(:tester => RubyTest),
          SpecifiedQueueWorker.new(:tester => RubyTest, :name => 'SpecifiedQueueClone'),
          SpecifiedQueue2Worker.new(:tester => RubyTest),
          SpecifiedTopicWorker.new(:tester => RubyTest),
          SpecifiedTopicWorker.new(:tester => RubyTest, :name => 'SpecifiedTopicClone'),
          SpecifiedTopic2Worker.new(:tester => RubyTest),
        ]
        ModernTimes::JMS::Publisher.setup_dummy_publishing(workers)
      end

      teardown do
        ModernTimes::JMS::Publisher.clear_dummy_publishing
      end

      should "directly call applicable workers" do
        publish(:ruby, RubyTest, 100..199, :queue_name => 'Default')
        publish(:ruby, RubyTest, 200..299, :queue_name => 'DefaultClone')
        publish(:ruby, RubyTest, 300..399, :queue_name => 'Dummy_Default')
        publish(:ruby, RubyTest, 400..599, :queue_name => 'MyQueueName')
        publish(:ruby, RubyTest, 600..699, :virtual_topic_name => 'MyTopicName')

        # The single instance of each class will be called so everyone will have all messages.
        assert_worker(nil, 'Default',             1, 100..199, 100, 100, 1)
        assert_worker(nil, 'DefaultClone',        1, 200..299, 100, 100, 1)
        assert_worker(nil, 'Dummy_Default',       1, 300..399, 100, 100, 1)
        assert_worker(nil, 'SpecifiedQueue',      1, 400..599, 200, 200, 1)
        assert_worker(nil, 'SpecifiedQueueClone', 1, 400..599, 200, 200, 1)
        assert_worker(nil, 'SpecifiedQueue2',     1, 400..599, 200, 200, 1)
        assert_worker(nil, 'SpecifiedTopic',      1, 600..699, 100, 100, 1)
        assert_worker(nil, 'SpecifiedTopicClone', 1, 600..699, 100, 100, 1)
        assert_worker(nil, 'SpecifiedTopic2',     1, 600..699, 100, 100, 1)
      end
    end
  end
end
