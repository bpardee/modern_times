module ModernTimes
  module QueueAdapter
    module InMem

      class Queue
        # Size of the queue before it write-blocks.  If 0, messages will be dropped.  If -1, then it's unlimited.
        attr_accessor :name, :max_size

        def initialize(name)
          @name            = name
          @max_size        = 0
          @mutex           = Mutex.new
          @read_condition  = ConditionVariable.new
          @write_condition = ConditionVariable.new
          @close_condition = ConditionVariable.new
          @array           = []
          @stopped         = false
        end

        def size
          @array.size
        end

        def stop
          @stopped = true
          @mutex.synchronize do
            @write_condition.broadcast
            until @array.empty?
              @close_condition.wait(@mutex)
            end
            @read_condition.broadcast
          end
        end

        def read
          @mutex.synchronize do
            while !@stopped do
              unless @array.empty?
                @write_condition.signal
                return @array.shift
              end
              @read_condition.wait(@mutex)
            end
            # We're not persistent, so even though we're stopped we're going to allow our workers to keep reading until the queue's empty
            unless @array.empty?
              @close_condition.signal
              return @array.shift
            end
          end
          return nil
        end

        def write(obj, response_options)
          # TODO: Let's allow various full_modes such as :block, :remove_oldest, ? (Currently only blocks)
          @mutex.synchronize do
            # We just drop the message if no workers have been configured yet
            while !@stopped
              if @max_size == 0
                ModernTimes.logger.warn "No worker for queue #{@name}, dropping message #{obj.inspect}"
                return
              end
              if @max_size < 0 || @array.size < @max_size
                @array << obj
                @read_condition.signal
                return
              end
              @write_condition.wait(@mutex)
            end
          end
        end

        def to_s
          "queue:#{@name}"
        end
      end
    end
  end
end
