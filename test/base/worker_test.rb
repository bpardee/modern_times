require 'modern_times'
require 'shoulda'
require 'test/unit'

class DummyWorker < ModernTimes::Base::Worker
end

module Base
  class WorkerTest <  Test::Unit::TestCase

    context 'a worker with no name specified' do
      setup do
        @worker = DummyWorker.new
        @worker.index = 2
        @worker.thread = 'dummy thread'
        @supervisor = DummyWorker.create_supervisor('dummy_manager')
      end

      should "have default name and proper supervisor and attributes" do
        assert_equal('Dummy', @worker.name)
        assert_equal(2, @worker.index)
        assert_equal('dummy thread', @worker.thread)
        assert_equal(ModernTimes::Base::Supervisor, @supervisor.class)
        assert_equal('dummy_manager', @supervisor.manager)
      end
    end

    context 'a worker with name specified' do
      setup do
        @worker = DummyWorker.new(:name => 'Foo')
      end

      should "have name specified and proper supervisor and attributes" do
        assert_equal('Foo', @worker.name)
      end
    end
  end
end
