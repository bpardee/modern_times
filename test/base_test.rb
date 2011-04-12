require 'modern_times'
require 'shoulda'
require 'test/unit'
require 'fileutils'

class DummyWorker
  include ModernTimes::Base::Worker
  attr_reader :opts, :setup_called, :count

  @@mutex = Mutex.new

  def self.reset
    @@total_count = 0
    @@workers = []
  end

  self.reset

  def self.total_count
    @@total_count
  end

  def self.workers
    @@workers
  end

  def initialize(opts={})
    @opts = opts
    @count = 0
    @@mutex.synchronize do
      @@workers << self
    end
  end

  # One time initialization prior to first thread
  def setup
    @setup_called = true
  end

  def start
    @stopped = false
    while !@stopped do
      sleep 1
      @count += 1
      @@mutex.synchronize do
        @@total_count += 1
      end
    end
  end

  def stop
    @stopped = true
  end

  def status
    "index=#{index}"
  end
end

class Dummy2Worker < DummyWorker

end

class BaseTest < Test::Unit::TestCase
  context 'a worker with no name specified' do
    setup do
      @worker = DummyWorker.new
      @worker.index = 2
      @worker.thread = 'dummy thread'
      @supervisor = DummyWorker.create_supervisor('dummy_manager', {:foo => 1})
    end

    should "have default name and proper supervisor and attributes" do
      assert_equal('Dummy', @worker.class.default_name)
      assert_equal('Dummy', @supervisor.name)
      assert_equal(2, @worker.index)
      assert_equal('dummy thread', @worker.thread)
      assert_equal(ModernTimes::Base::Supervisor, @supervisor.class)
      assert_equal('dummy_manager', @supervisor.manager)
    end
  end

  context 'a worker with name specified' do
    setup do
      @worker = DummyWorker.new(:name => 'Foo')
      @supervisor = DummyWorker.create_supervisor('dummy_manager', {:name => 'Foo'})
    end

    should "have name specified and proper supervisor and attributes" do
      assert_equal('Foo', @supervisor.name)
    end
  end

  context 'a default worker' do
    setup do
      DummyWorker.reset
      @start_time = Time.now
      @manager = ModernTimes::Manager.new
      @manager.add(DummyWorker, 2, {:foo => 42})
      sleep 5
      @manager.stop
      @manager.join
      @end_time = Time.now
    end

    should "be performing work" do
      w = DummyWorker.workers
      w = w.reverse if w[0].index == 1
      assert_equal 2, w.size
      (0..1).each do |i|
        worker = w[i]
        assert worker.count >= 3
        assert worker.count <= 8
        assert worker.index == i
        assert worker.status == "index=#{worker.index}"
      end
      assert DummyWorker.total_count >= 8
      assert DummyWorker.total_count <= 14
      assert (@end_time-@start_time) < 14.0
      assert w[0].supervisor == w[1].supervisor
      assert w[0].supervisor.name == 'Dummy'
      assert w[0].setup_called
      assert !w[1].setup_called
    end
  end

  context 'a disallowed worker' do
    setup do
      DummyWorker.reset
      @manager = ModernTimes::Manager.new(:domain => 'DisallowedWorker')
      @manager.allowed_workers = []
    end

    should "not be allowed" do
      e = assert_raises ModernTimes::Exception do
        @manager.add(DummyWorker, 2, {:foo => 42})
      end
      assert_match %r%is not an allowed worker%, e.message

      e = assert_raises ModernTimes::Exception do
        @manager.add('FdajfsdklasdfWorker', 2, {:foo => 42})
      end
      assert_match %r%Invalid class%, e.message
    end
  end

  context 'multiple workers' do
    setup do
      DummyWorker.reset
      @manager = ModernTimes::Manager.new(:domain => 'AllowedWorker')
      @manager.allowed_workers = [DummyWorker, Dummy2Worker]
      @manager.add(DummyWorker, 2, {:foo => 42})
      @manager.add(DummyWorker, 1, {:name => 'OtherDummy'})
      @manager.add(Dummy2Worker, 2, {:name => 'SecondDummy'})
      sleep 5
      @manager.stop
      @manager.join
      @end_time = Time.now
    end

    should "work" do
      w = DummyWorker.workers
      s = w.map {|worker| worker.supervisor}.uniq
      assert_equal 5, w.size
      assert_equal 3, s.size
      (0..4).each do |i|
        worker = w[i]
        assert worker.count >= 3
        assert worker.count <= 8
      end
      assert DummyWorker.total_count >= 20
      assert DummyWorker.total_count <= 35
      super_names = s.map {|sup| sup.name}.sort
      assert_equal ['Dummy', 'OtherDummy', 'SecondDummy'], super_names
    end
  end

  context 'manager with persist_file set' do
    setup do
      DummyWorker.reset
      persist_file = "/tmp/modern_times_persist_#{$$}.state"
      @manager = ModernTimes::Manager.new(:domain => 'PersistManager', :persist_file => persist_file)
      @manager.allowed_workers = [DummyWorker, Dummy2Worker]
      @manager.add(DummyWorker, 2, {:foo => 42})
      @manager.add(DummyWorker, 1, {:name => 'OtherDummy'})
      @manager.add(Dummy2Worker, 2, {:name => 'SecondDummy'})
      @manager.stop
      @manager.join
      DummyWorker.reset
      @manager2 = ModernTimes::Manager.new(:domain => 'PersistManager2', :persist_file => persist_file)
      sleep 5
      @manager2.stop
      @manager2.join
      FileUtils.rm persist_file
    end

    should "recreate workers and supervisors correctly" do
      w = DummyWorker.workers
      s = w.map {|worker| worker.supervisor}.uniq
      assert_equal 5, w.size
      assert_equal 3, s.size
      (0..4).each do |i|
        worker = w[i]
        assert worker.count >= 3
        assert worker.count <= 8
      end
      assert DummyWorker.total_count >= 20
      assert DummyWorker.total_count <= 35
      super_names = s.map {|sup| sup.name}.sort
      assert_equal ['Dummy', 'OtherDummy', 'SecondDummy'], super_names
    end
  end

  context 'manager' do
    setup do
      DummyWorker.reset
      persist_file = "/tmp/modern_times_persist_#{$$}.state"
      @domain = 'JMXManagerDomain'
      @manager = ModernTimes::Manager.new(:domain => @domain)
      @manager.allowed_workers = [DummyWorker, Dummy2Worker]

      @server = JMX.simple_server
      @client = JMX.connect
      @manager_mbean  = @client["#{@domain}:type=Manager"]
    end

    teardown do
      @manager.stop
      @manager.join
      @server.stop
    end

    should "allow JMX to start and query workers" do
      @manager_mbean.start_worker('DummyWorker',  2, '{"foo":42}')
      @manager_mbean.start_worker('DummyWorker',  1, '{"name":"OtherDummy"}')
      @manager_mbean.start_worker('Dummy2Worker', 2, '{"name":"SecondDummy"}')
      #puts "allowed workers=#{@manager_mbean.allowed_workers[0].class.name}"
      assert_equal ['DummyWorker', 'Dummy2Worker'], @manager_mbean.allowed_workers.to_a

      dummy_bean        = @client["#{@domain}:worker=Dummy,type=Worker"]
      other_dummy_bean  = @client["#{@domain}:worker=OtherDummy,type=Worker"]
      second_dummy_bean = @client["#{@domain}:worker=SecondDummy,type=Worker"]
      assert 2, dummy_bean.worker_count
      assert 1, other_dummy_bean.worker_count
      assert 2, second_dummy_bean.worker_count
      other_dummy_bean.worker_count = 3
      assert 3, other_dummy_bean.worker_count
    end
  end
end
