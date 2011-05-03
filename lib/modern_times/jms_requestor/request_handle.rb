require 'timeout'
require 'yaml'

module ModernTimes
  module JMSRequestor
    class RequestHandle
      def initialize(requestor, jms_message_id, start, timeout, &reconstruct_block)
        @requestor         = requestor
        @reply_queue       = requestor.reply_queue
        @jms_message_id    = jms_message_id
        @start             = start
        @timeout           = timeout
        @reconstruct_block = reconstruct_block
      end

      def read_response
        response = nil
        opts = { :destination => @reply_queue, :selector => "JMSCorrelationID = '#{@jms_message_id}'" }
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
        raise Timeout::Error, "Timeout waiting for for response from message #{@jms_message_id} on queue #{@reply_queue}" unless response
        if error_yaml = response['Exception']
          raise ModernTimes::RemoteException.from_hash(YAML.load(error_yaml))
        end
        response = @requestor.marshaler.unmarshal(response.data)
        if @reconstruct_block
          response = @reconstruct_block.call(response)
        end
        return response
      end
    end
  end
end
