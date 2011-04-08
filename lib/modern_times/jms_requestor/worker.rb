module ModernTimes
  module JMSRequestor

    # Base Worker Class for any class that will be processing messages from queues
    module Worker
      include ModernTimes::JMS::Worker

      def self.included(base)
        base.extend(ModernTimes::JMS::Worker::ClassMethods)
      end

      def perform(object)
        response = request(object)
        session.producer(:destination => message.reply_to) do |producer|
          reply_message = session.message(marshal(response))
          reply_message.jms_correlation_id = message.jms_message_id
          #producer.send_with_retry(reply_message)
          producer.send(reply_message)
        end
      end

      def request(object)
        raise "#{self}: Need to override request method in #{self.class.name} in order to act on #{object}"
      end
    end
  end
end
