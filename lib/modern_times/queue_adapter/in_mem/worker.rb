# Handle Messaging and Queuing using JMS
module ModernTimes
  module QueueAdapter
    module InMem
      class Worker
        attr_reader :stopped

        def initialize(marshaler, queue)
          @marshaler = marshaler
          @queue     = queue
        end

        def receive_message
          @queue.read(self)
        end

        def acknowledge_message(msg)
        end

        def send_response(original_message, marshaled_object)
          # We unmarshal so our workers get consistent messages regardless of the adapter
          do_send_response(original_message, @marshaler.unmarshal(marshaled_object))
        end

        def send_exception(original_message, e)
          # TODO: I think exceptions should be recreated fully so no need for marshal/unmarshal?
          do_send_response(original_message, ModernTimes::RemoteException.new(e))
        end

        def message_to_object(msg)
          # The publisher has already unmarshaled the object to save hassle here.
          return msg
        end

        def handle_failure(message, fail_queue_name)
          # TODO: Mode for persisting to flat file?
          ModernTimes.logger.warn("Dropping message that failed: #{message}")
        end

        def stop
          @stopped = true
        end

        def close
          return if @closed
          ModernTimes.logger.debug { "Closing #{self}" }
          @closed = true
        end

        ## End of required override methods for worker adapter
        private

        def do_send_response(object)
          return unless @queue.reply_queue
          @queue.reply_queue.write_response(object, config.name)
          return true
        end
      end
    end
  end
end
