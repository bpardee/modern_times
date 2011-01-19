require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'modern_times'
require 'range_queue_strategy'
require 'range_queue_worker'

class WorkerManagerTest < Test::Unit::TestCase
  context 'on single strategy' do
    setup do
      @range = 1..100
    end

    should 'work' do
      strategy = RangeQueueStrategy.new(@range)
      manager = ModernTimes::WorkerManager.new
      worker = RangeQueueWorker.new
      thread_count = 10
      manager.add(strategy, worker, thread_count, 1)
      sleep(2)
      manager.stop
      assert_equal @range.to_a, worker.results.sort
    end
  end

  context 'on multiple strategies' do
    setup do
      @ranges = [1..100, 101..200, 201..300]
    end

    should 'work' do
      [nil, 1].each do |poll_sleep|
        strategies = @ranges.map {|range| RangeQueueStrategy.new(range) }
        manager = ModernTimes::WorkerManager.new
        workers = [RangeQueueWorker.new, RangeQueueWorker.new, RangeQueueWorker.new]
        thread_count = 10
        strategies.each_index do |i|
          manager.add(strategies[i], workers[i], thread_count, poll_sleep)
        end
        sleep(2)
        manager.stop
        strategies.each_index do |i|
          assert_equal @ranges[i].to_a, workers[i].results.sort
        end
      end
    end
  end
end