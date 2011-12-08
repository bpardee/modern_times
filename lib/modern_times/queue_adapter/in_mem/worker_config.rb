# Handle Messaging and Queuing using JMS
module ModernTimes
  module QueueAdapter
    module InMem

      # This is the InMem Adapter that corresponds to ModernTimes::WorkerConfig (also known as parent)
      class WorkerConfig
        include Rumx::Bean

        bean_reader :queue_name,     :string,  'Name of the queue'
        bean_reader :queue_size,     :integer, 'Current count of messages in the queue'
        bean_reader :queue_max_size, :integer, 'Max messages allowed in the queue'

        attr_reader :stopped

        def initialize(parent, queue_name, topic_name, options, response_options)
          @parent = parent
          @queue_max_size = options[:queue_max_size] || 100
          @queue = Factory.get_worker_queue(parent.name, queue_name, topic_name, @queue_max_size)
        end

        def default_marshal_type
          :none
        end

        def create_worker
          Worker.new(@parent.marshaler, @queue)
        end

        def stop
          return if @stopped
          ModernTimes.logger.debug { "Closing #{self}" }
          @queue.stop
          @stopped = true
        end

        ## End of required override methods for worker_config adapter

        def queue_name
          @queue.name
        end

        def queue_size
          @queue.size
        end

        def queue_max_size
          @queue.max_size
        end
      end
    end
  end
end
