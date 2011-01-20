require 'modern_times/thread'

module ModernTimes
  class WorkerManager
    def initialize
      @strategy_hash = {}
      @is_stopped = false
    end

    # Input:
    #   queue_strategy - should implement thread-safe versions of create_session, receive, and stop.
    #   worker - contains a perform method which operates on the receive objects
    #   thread_count - number of threads to receive and work on objects
    #   poll-sleep - set for receive's that are polling, this is the sleep time between non-data receives (which should return nil)
    def add(queue_strategy, worker, thread_count, poll_sleep=nil)
      threads = []
      thread_count.times do
        threads << ModernTimes::Thread.new do
          session = queue_strategy.create_session rescue nil
          until @is_stopped
            value = queue_strategy.receive(session)
            if value
              begin
                worker.perform(value)
              rescue Exception =>e
                queue_strategy.failed(session, value)
              end
            elsif poll_sleep
              sleep poll_sleep
            else
              ModernTimes.logger.debug("Thread #{session} exited because it received a nil value and poll_sleep is NOT set")
              break
            end
          end
          queue_strategy.destroy_session rescue nil
        end
      end
      @strategy_hash[queue_strategy] = threads
    end

    def stop
      @is_stopped = true
      @strategy_hash.each do |queue_strategy|
        queue_strategy.stop rescue nil
      end
      @strategy_hash.each_value do |threads|
        threads.each { |t| t.join }
      end
    end
  end
end
