module ModernTimes
  module QueueAdapter
    module InMem

      class ReplyQueue
        def initialize(name)
          @queue = Queue.new(name)
          @queue.size = -1
        end

        def stop
          @queue.stop
        end

        def read_response(timeout)
          Timeout.timeout(timeout) do
            return @queue.read
          end
        rescue Timeout::Error => e
          return nil
        end

        def write(obj, worker_name)
          @queue.write([obj, worker_name])
        end
      end
    end
  end
end
