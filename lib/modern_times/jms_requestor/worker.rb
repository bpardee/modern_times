module ModernTimes
  module JMSRequestor

    # Base Worker Class for any class that will be processing messages from queues
    class Worker < ModernTimes::JMS::Worker
      # Make JMSRequestor::Supervisor our supervisor
      #supervisor Supervisor

      def on_message(message)
        @reply_queue = message.get_string_property(Java::OrgHornetqCoreClientImpl::ClientMessageImpl::REPLYTO_HEADER_NAME)
        @message_id = message.get_string_property(MESSAGE_ID)
        super
      end

      def perform(object)
        response = request(object)
        session.producer(@reply_queue) do |producer|
          reply_message = marshal(session, response, false)
          reply_message.put_string_property(MESSAGE_ID, @message_id)
          producer.send_with_retry(reply_message)
        end
      end

      def request(object)
        raise "#{self}: Need to override request method in #{self.class.name} in order to act on #{object}"
      end
    end
  end
end