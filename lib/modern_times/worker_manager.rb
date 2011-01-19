require 'modern_times/thread'

module ModernTimes
  class WorkerManager
    # Input is an queue_strategy which should implement thread-safe versions of receive and stop and
    # an array of queue config objects which is just a hash as follows:
    #  queue:
    #    name: MyQueue
    #    class: MyQueueWorker
    #    workers: 50              (optional, defaults to 1)
    #    fail_queue: MyQueueFail (optional, defaults to nil)
    def initialize
      @strategy_hash = {}
      @is_stopped = false
    end

    def add(queue_strategy, worker, thread_count, poll_sleep=nil)
      threads = []
      thread_count.times do
        threads << ModernTimes::Thread.new do
          session_info = queue_strategy.create_session
          until @is_stopped
            value = queue_strategy.receive(session_info)
            if value
              begin
                worker.perform(value)
              rescue Exception =>e
                queue_strategy.failed(session_info, value)
              end
            elsif poll_sleep
              sleep poll_sleep
              break if @is_stopped
            else
              ModernTimes.logger.debug("Thread #{session_info} exited because it received a nil value and poll_sleep is NOT set")
              break
            end
          end
        end
      end
      @strategy_hash[queue_strategy] = threads
    end

    def stop
      @is_stopped = true
      @strategy_hash.each do |queue_strategy|
        queue_strategy.stop if queue_strategy.respond_to?(:stop)
      end
      @strategy_hash.each_value do |threads|
        threads.each { |t| t.join }
      end
    end
  end
end
