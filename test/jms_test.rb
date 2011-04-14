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
    @@mutex.synchronize do
      @@workers[self.class.name] ||= []
      @@workers[self.class.name] << self
    end
    @hash = Hash.new(0)
  end

  def self.workers(worker_klass)
    @@workers[worker_klass.name]
  end

  def self.reset_workers
    @@workers = {}
  end

  def add_message(i)
    @hash[i] += 1
  end

  def message_count
    puts "hash=#{@hash.inspect}"
    @hash.values.reduce(:+)
  end

  def messages
    @hash.keys
  end
end

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
  end

  def self.included(base)
    base.extend(ModuleMethods)
  end

  def perform(obj)
    add_message(obj['bar']['message'])
  end
end

module BSONTest
  include ModernTimes::MarshalStrategy::BSON
  include HashTest
end

module JSONTest
  include ModernTimes::MarshalStrategy::JSON
  include HashTest
end

module RubyTest
  include ModernTimes::MarshalStrategy::Ruby

  class MyClass
    attr_reader :i
    def initialize(i)
      @i = i
    end
  end

  def self.create_obj(i)
    MyClass.new(i)
  end

  def perform(obj)
    add_message(obj.i)
  end
end

module StringTest
  include ModernTimes::MarshalStrategy::String

  def self.create_obj(i)
    "Message #{i}"
  end

  def perform(str)
    if str =~ /^Message (\d+)$/
      add_message($1.to_i)
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
  queue_name 'MyQueueName'
  include WorkerHelper
end

class SpecifiedQueue2Worker
  include ModernTimes::JMS::Worker
  queue_name 'MyQueueName'
  include WorkerHelper
end

class SpecifiedTopicWorker
  include ModernTimes::JMS::Worker
  virtual_topic_name 'MyTopicName'
  include WorkerHelper
end

class SpecifiedTopic2Worker
  include ModernTimes::JMS::Worker
  virtual_topic_name 'MyTopicName'
  include WorkerHelper
end

class JMSTest < Test::Unit::TestCase
  def publish(marshal_module, range, options)
    publisher = ModernTimes::JMS::Publisher.new(options.merge(:marshal => marshal_module))
    puts "Publishing #{range} to #{publisher}"
    range.each do |i|
      obj = marshal_module.create_obj(i)
      publisher.publish(obj)
    end
  end
  
  def assert_worker(worker_klass, worker_count, range, min, max, instance_count)
    puts "Checking #{worker_klass.inspect}"
    if worker_klass.kind_of?(Array)
      workers = []
      worker_klass.each {|klass| workers.concat(WorkerHelper.workers(klass))}
    else
      workers = WorkerHelper.workers(worker_klass)
    end
    assert_equal worker_count, workers.size
    all = []
    workers.each do |worker|
      msg_count = worker.message_count
      assert msg_count >= min, "#{msg_count} is not between #{min} and #{max}"
      assert msg_count <= max, "#{msg_count} is not between #{min} and #{max}"
      # Make sure no duplicate messages
      assert msg_count == worker.messages.size, "#{msg_count} is not == #{worker.messages.size}"
      all.concat(worker.messages)
    end
    all.sort!
    assert_equal all, (range.to_a*instance_count).sort
  end

  context 'jms' do
    setup do
      config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), 'jms.yml'))).result(binding))
      ModernTimes::JMS::Connection.init(config)
    end

    #[BSONTest, JSONTest, RubyTest, StringTest].each do |marshal_module|
    [BSONTest, JSONTest, StringTest].each do |marshal_module|
      marshal_module.name =~ /(.*)Test/
      marshal_type = $1

      context "marshaling with #{marshal_type}" do
        setup do
          @manager = ModernTimes::Manager.new(:domain => "Uniquize_#{marshal_module.name}")
        end

        teardown do
          if @manager
            @manager.stop
            @manager.join
          end
        end

        should "operate on queues and topics" do
          WorkerHelper.reset_workers
          [DefaultWorker, Dummy::DefaultWorker, SpecifiedQueueWorker, SpecifiedQueue2Worker, SpecifiedTopicWorker, SpecifiedTopic2Worker].each do |worker_klass|
            worker_klass.send(:include, marshal_module)
          end
          @manager.add(DefaultWorker, 3)
          @manager.add(DefaultWorker, 2, :name => 'DefaultClone')
          @manager.add(Dummy::DefaultWorker, 4)
          @manager.add(SpecifiedQueueWorker, 3)
          @manager.add(SpecifiedQueueWorker, 2, :name => 'SpecifiedQueueClone')
          @manager.add(SpecifiedQueue2Worker, 2)
          @manager.add(SpecifiedTopicWorker, 3)
          @manager.add(SpecifiedTopicWorker, 2, :name => 'SpecifiedTopicClone')
          @manager.add(SpecifiedTopic2Worker, 2)

          sleep 1

          publish(marshal_module, 100..199, :queue_name => 'Default')
          publish(marshal_module, 200..299, :queue_name => 'Dummy_Default')
          publish(marshal_module, 300..499, :queue_name => 'MyQueueName')
          publish(marshal_module, 500..599, :virtual_topic_name => 'MyTopicName')

          # Let the workers do their thing
          sleep 5

          # DefaultWorker should have 5 instances running with each worker handling between 10-30 messages in the range 100.199
          assert_worker(DefaultWorker,                                5, 100..199, 10, 30, 1)
          assert_worker(Dummy::DefaultWorker,                         4, 200..299, 15, 35, 1)
          assert_worker([SpecifiedQueueWorker,SpecifiedQueue2Worker], 7, 300..499, 20, 40, 1)
          assert_worker(SpecifiedTopicWorker,                         5, 500..599, 30, 50, 2)
          assert_worker(SpecifiedTopic2Worker,                        2, 500..599, 35, 65, 1)
        end
      end
    end
  end
end
