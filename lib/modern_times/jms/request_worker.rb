module ModernTimes
  module JMS

    # Base Worker Class for any class that will be processing requests from queues and replying
    module RequestWorker
      include Worker
      # Dummy requesting needs access to this
      attr_reader :marshaler

      module ClassMethods
        # Define the marshaling and time_to_live that will occur on the response
        def response(options)
          @response_options = options
        end

        def response_options
          # Get the response marshaler, defaulting to the request marshaler
          @response_options
        end

        # By default, exceptions don't get forwarded to a fail queue (they get returned to the caller)
        def default_fail_queue_target
          false
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
        response_options = self.class.response_options || {}
        @marshal_type = (response_options[:marshal] || :ruby).to_s
        @marshaler    = MarshalStrategy.find(@marshal_type)
        # Time in msec until the message gets discarded, should be more than the timeout on the requestor side
        @time_to_live = response_options[:time_to_live]
        @persistent   = response_options[:persistent]
      end

      def perform(object)
        response = request(object)
        send_response(@marshal_type, @marshaler, response)
        post_request(object)
      rescue Exception => e
        on_exception(e)
      end

      def request(object)
        raise "#{self}: Need to override request method in #{self.class.name} in order to act on #{object}"
      end

      # Handle any processing that you want to perform after the reply
      def post_request(object)
      end

      #########
      protected
      #########

      def on_exception(e)
        begin
          stat = send_response(:string, ModernTimes::MarshalStrategy::String, "Exception: #{e.message}") do |reply_message|
            reply_message['mt:exception'] = ModernTimes::RemoteException.new(e).to_hash.to_yaml
          end
        rescue Exception => e
          ModernTimes.logger.error("Exception in exception reply: #{e.message}")
          log_backtrace(e)
        end

        # Send it on to the fail queue if it was explicitly set
        super
      end

      # Sending marshaler is redundant but saves a lookup
      def send_response(marshal_type, marshaler, object)
        return false unless message.reply_to
        begin
          session.producer(:destination => message.reply_to) do |producer|
            # For time_to_live and jms_deliver_mode, first use the local response_options if they're' set, otherwise
            # use the value from the message attributes if they're' set
            time_to_live = @time_to_live || message['mt:response:time_to_live']
            persistent   = @persistent
            persistent = (message['mt:response:persistent'] == 'true') if persistent.nil? && message['mt:response:persistent']
            # If persistent isn't set anywhere, then default to true unless time_to_live has been set
            persistent = !time_to_live if persistent.nil?
            # The reply is persistent if we explicitly set it or if we don't expire
            producer.delivery_mode_sym = persistent ? :persistent : :non_persistent
            producer.time_to_live = time_to_live.to_i if time_to_live
            reply_message = ModernTimes::JMS.create_message(session, marshaler, object)
            reply_message.jms_correlation_id = message.jms_message_id
            reply_message['mt:marshal'] = marshal_type.to_s
            reply_message['mt:worker'] = self.name
            yield reply_message if block_given?
            producer.send(reply_message)
          end
        rescue Exception => e
          ModernTimes.logger.error {"Error attempting to send response: #{e.message}"}
          log_backtrace(e)
        end
        return true
      end
    end
  end
end
