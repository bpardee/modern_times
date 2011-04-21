require 'timeout'

module ModernTimes
  module JMSRequestor
    class RequestHandle
      def initialize(requestor, message, start, timeout)
        @requestor   = requestor
        @reply_queue = requestor.reply_queue
        @message     = message
        @start       = start
        @timeout     = timeout
      end

      def read_response
        response = nil
        opts = { :destination => @reply_queue, :selector => "JMSCorrelationID = '#{@message.jms_message_id}'" }
        #opts = { :destination => @reply_queue }
        #opts = {:queue_name => 'foobarzulu'}
        ModernTimes::JMS::Connection.session_pool.consumer(opts) do |session, consumer|
          leftover_timeout = ((@start + @timeout - Time.now) * 1000).to_i
          if leftover_timeout > 100
            response = consumer.receive(leftover_timeout)
          else
            #response = consumer.receive_no_wait
            response = consumer.receive(100)
          end
        end
        raise Timeout::Error, "Timeout waiting for for response from message #{@message.jms_message_id} on queue #{@reply_queue}" unless response
        return @requestor.marshaler.unmarshal(response.data)
      end
    end
  end
end
