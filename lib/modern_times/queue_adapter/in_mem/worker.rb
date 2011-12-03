# Handle Messaging and Queuing using JMS
module ModernTimes
  module QueueAdapter
    module InMem
      class Worker
        include Rumx::Bean

        bean_reader :queue_name,     :string,  'Name of the queue'
        bean_reader :queue_size,     :integer, 'Current count of messages in the queue'
        bean_reader :queue_max_size, :integer, 'Max messages allowed in the queue'

        def initialize(worker_config, queue_name, topic_name, options, response_options)
          @queue_max_size = options[:queue_max_size] || 100
          @queue = Factory.get_worker_queue(worker_config.name, queue_name, topic_name, @queue_max_size)
          # TODO: Let's move this up farther so we don't have to deal with it here?
          @marshal_type = (response_options[:marshal] || :none).to_s
          @marshaler    = MarshalStrategy.find(@marshal_type)
        end

        def queue_name
          @queue.name
        end
        
        def queue_size
          @queue.size
        end

        def queue_max_size
          @queue.max_size
        end

        def receive_message
          @queue.read
        end

        def acknowledge_message(msg)
        end

        def send_response(original_message, object)
          # We marshal and unmarshal so our workers get consistent messages regardless of the adapter
          do_send_response(original_message, @marshaler.unmarshal(@marshaler.marshal(object)))
        end

        def send_exception(original_message, e)
          # TODO: I think exceptions should be recreated fully so need for marshal/unmarshal?
          do_send_response(original_message, ModernTimes::RemoteException.new(e))
        end

        def message_to_object(msg)
          # The publisher has already unmarshaled the object to save hassle here.
          return msg
        end

        def handle_failure(message, fail_queue_name)
          ModernTimes.logger.warn("Dropping message that failed: #{message}")
        end

        def close
          return if @closed
          ModernTimes.logger.debug { "Closing #{self}" }
          @queue.stop
          @closed = true
        end

        private

        def do_send_response(object)
          return unless @queue.reply_queue
          @queue.reply_queue.write(object, config.name)
          return true
        end
      end
    end
  end
end
