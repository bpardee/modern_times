# Handle Messaging and Queuing using JMS
module ModernTimes
  module QueueAdapter
    module JMS
      class WorkerConfig
        include Rumx::Bean

        bean_reader :queue_size,     'Current count of messages in the queue'
        bean_reader :queue_max_size, 'Max messages allowed in the queue'

        attr_reader :parent, :destination, :marshal_type, :marshaler, :time_to_live, :persistent, :stopped

        def initialize(parent, queue_name, topic_name, options, response_options)
          @parent       = parent
          @destination  = {:queue_name => queue_name} if queue_name
          @destination  = {:topic_name => topic_name} if topic_name
          @marshal_type = (response_options[:marshal] || :ruby).to_s
          @marshaler    = MarshalStrategy.find(@marshal_type)
          # Time in msec until the message gets discarded, should be more than the timeout on the requestor side
          @time_to_live = response_options[:time_to_live]
          @persistent   = response_options[:persistent]
        end

        # Default marshal type for the response
        def default_marshal_type
          :ruby
        end

        def create_worker
          Worker.new(@worker_config, @queue)
        end

        def stop
          @stopped = true
        end
      end
    end
  end
end
