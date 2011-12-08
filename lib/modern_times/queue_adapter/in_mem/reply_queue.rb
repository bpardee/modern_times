module ModernTimes
  module QueueAdapter
    module InMem

      class ReplyQueue
        def initialize(name)
          @name            = name
          @mutex           = Mutex.new
          @read_condition  = ConditionVariable.new
          @array           = []
        end

        def read_response(timeout)
          @mutex.synchronize do
            return @array.shift unless @array.empty?
            timed_read_condition_wait(timeout)
            return @array.shift
          end
          return nil
        end

        def write_response(obj, worker_name)
          @mutex.synchronize do
            @array << [obj, worker_name]
            @read_condition.signal
            return
          end
        end

        def to_s
          "reply_queue:#{@name}"
        end

        #######
        private
        #######

        if RUBY_PLATFORM == 'jruby' || RUBY_VERSION[0,3] != '1.8'
          def timed_read_condition_wait(timeout)
            # This method not available in MRI 1.8
            @read_condition.wait(@mutex, timeout)
          end
        else
          require 'timeout'
          def timed_read_condition_wait(timeout)
            Timeout.timeout(timeout) do
              @read_condition.wait(@mutex)
            end
          rescue Timeout::Error => e
          end
        end

      end
    end
  end
end
