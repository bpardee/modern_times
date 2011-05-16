module ModernTimes
  module JMS

    # Base Worker Class for any class that will be processing messages from queues
    module RequestWorker
      include Worker
      # Dummy requesting needs access to this
      attr_reader :marshaler

      module ClassMethods
        # Define the marshaling that will occur on the response
        def response_marshal(marshaler)
          @response_marshal = marshaler
        end

        def response_marshal_sym
          # Get the response marshaler, defaulting to the request marshaler
          @response_marshal
        end
      end

      def self.included(base)
        # The price we pay for including rather than extending
        base.extend(ModernTimes::Base::Worker::ClassMethods)
        base.extend(Worker::ClassMethods)
        base.extend(ClassMethods)
      end

      def initialize(opts={})
        super
        @marshal_sym = self.class.response_marshal_sym || :ruby
        @marshaler   = MarshalStrategy.find(@marshal_sym)
      end

      def perform(object)
        response = request(object)
        session.producer(:destination => message.reply_to) do |producer|
          reply_message = ModernTimes::JMS.create_message(session, @marshaler, response)
          reply_message.jms_correlation_id = message.jms_message_id
          reply_message.jms_delivery_mode = ::JMS::DeliveryMode::NON_PERSISTENT
          reply_message['worker']  = self.name
          reply_message['marshal'] = @marshal_sym.to_s
          producer.send(reply_message)
        end
      rescue Exception => e
        ModernTimes.logger.error("Exception: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
        begin
          session.producer(:destination => message.reply_to) do |producer|
            reply_message = ModernTimes::JMS.create_message(session, ModernTimes::MarshalStrategy::String, "Exception: #{e.message}")
            reply_message.jms_correlation_id = message.jms_message_id
            reply_message['worker']    = self.name
            reply_message['exception'] = ModernTimes::RemoteException.new(e).to_hash.to_yaml
            producer.send(reply_message)
          end
        rescue Exception => e
          ModernTimes.logger.error("Exception in exception reply: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
        end
        raise
      end

      def request(object)
        raise "#{self}: Need to override request method in #{self.class.name} in order to act on #{object}"
      end
    end
  end
end
