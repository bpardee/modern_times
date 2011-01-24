require 'modern_times/thread'

module ModernTimes
  class WorkerManager
    include Stoppable

    class MyThread < ModernTimes::Thread
      attr_reader :session

      def initialize(parent, queue_strategy, worker, poll_sleep)
        @session = queue_strategy.create_session if queue_strategy.respond_to?(:create_session)
        super() do
          until parent.stopped?
            value = queue_strategy.receive(@session)
            if value
              begin
                worker.perform(value)
              rescue Exception =>e
                ModernTimes.logger.warn("Session #{@session} failed for value=#{value} with exception #{e.message}")
                ModernTimes.logger.debug(e.backtrace.join("\n"))
                queue_strategy.failed(@session, value) if queue_strategy.respond_to?(:failed)
              end
            elsif poll_sleep
              sleep poll_sleep
            else
              ModernTimes.logger.debug("Thread #{@session} exited because it received a nil value and poll_sleep is NOT set")
              break
            end
          end
          queue_strategy.destroy_session(@session) if queue_strategy.respond_to?(:destroy_session)
        end
      end
    end

    def initialize
      @strategy_hash = {}
    end

    # Input:
    #   queue_strategy - should implement thread-safe versions of create_session, receive, and stop.
    #   worker - contains a perform method which operates on the receive objects
    #   thread_count - number of threads to receive and work on objects
    #   poll-sleep - set for receive's that are polling, this is the sleep time between non-data receives (which should return nil)
    def add(queue_strategy, worker, thread_count, poll_sleep=nil)
      threads = Array.new(thread_count) { MyThread.new(self, queue_strategy, worker, poll_sleep) }
      @strategy_hash[queue_strategy] = threads
    end

    def stop
      super
      @strategy_hash.each do |queue_strategy|
        if queue_strategy.respond_to?(:interrupt_session)
          @strategy_hash[queue_strategy].each do |thread|
            queue_strategy.interrupt_session(thread.session)
          end
        end
        queue_strategy.stop if queue_strategy.respond_to?(:stop)
      end
      @strategy_hash.each_value do |threads|
        threads.each { |t| t.join }
      end
    end
  end
end
