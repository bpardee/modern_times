require 'timeout'

module ModernTimes
  module HornetQRequestor
    class RequestHandle
      def initialize(requestor, message_id, start, timeout)
        @requestor   = requestor
        @reply_queue = requestor.reply_queue
        @message_id  = message_id
        @start       = start
        @timeout     = timeout
      end

      def read_response
        message = nil
        leftover_timeout = ((@start + @timeout - Time.now) * 1000).to_i
        ModernTimes::HornetQ::Client.session_pool.session do |s|
          consumer = nil
          begin
            consumer = s.create_consumer(@reply_queue, "#{MESSAGE_ID}='#{@message_id}'")
            if leftover_timeout > 0
              message = consumer.receive(leftover_timeout)
            else
              message = consumer.receive(1)
            end
            puts "funked at #{Time.now.to_f}" unless message
            consumer.receive_immediate unless message
          ensure
            consumer.close if consumer
          end
        end
        raise Timeout::Error, "Timeout waiting for message #{@message_id} on queue #{@reply_queue}" unless message
        return @requestor.unmarshal(message)
      end
    end
  end
end

#handle = Intercept::Client.async_cair(bank_account_array, tracking_number, timeout)
#... do other stuff ...
#begin
#  # Following call will block until the queue receives the reply or what's left of the timeout expires
#  intercept_statuses = handle.read_response
#  ... process intercept statuses ...
#rescue Timeout::Error => e
#  Rails.logger.warn "We didn't receive a reply back on the queue in time"
#rescue Intercept::Error => e
#  Rails.logger.warn "Error during intercept call: #{e.message}"
#end
