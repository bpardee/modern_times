# Handle Messaging and Queuing using JMS
module ModernTimes
  module QueueAdapter
    class JMSPublisher

      #attr_reader :persistent, :marshaler, :reply_queue

      def initialize(dest_options, misc_options)
        @real_dest_options = dest_options.dup
        virtual_topic_name = @real_dest_options.delete(:virtual_topic_name)
        @real_dest_options[:topic_name] = "VirtualTopic.#{virtual_topic_name}" if virtual_topic_name

        @persistent_sym = misc_options[:persistent] ? :persistent : :non_persistent
        @time_to_live = misc_options[:time_to_live]
        @response_time_to_live_str = misc_options[:response_time_to_live] && misc_options[:response_time_to_live].to_s
        @response_persistent_str = nil
        @response_persistent_str = (!!misc_options[:response_persistent]).to_s unless misc_options[:response_persistent].nil?

        @is_response = misc_options[:response] || !@response_time_to_live_str.nil? || !@response_persistent_str.nil?
        @reply_queue = nil
        if @is_response
          ModernTimes::JMS::Connection.session_pool.session do |session|
            @reply_queue = session.create_destination(:queue_name => :temporary)
          end
        end
      end

      def response?
        @is_response
      end

      # Publish the given object and return the message_id.
      def publish(marshaled_object, marshal_sym, marshal_type, props)
        message = nil
        ModernTimes::JMS::Connection.session_pool.producer(@real_dest_options) do |session, producer|
          producer.time_to_live      = @time_to_live if @time_to_live
          producer.delivery_mode_sym = @persistent_sym
          message = ModernTimes::JMS.create_message(session, marshaled_object, marshal_type)
          message.jms_reply_to                = @reply_queue if @reply_queue
          message['mt:marshal']               = marshal_sym.to_s
          message['mt:response:time_to_live'] = @response_time_to_live_str if @response_time_to_live_str
          message['mt:response:persistent']   = @response_persistent_str unless @response_persistent_str.nil?
          props.each do |key, value|
            message.send("#{key}=", value)
          end
          producer.send(message)
        end
        return message.jms_message_id
      end

      # Creates a block for reading the responses for a given message_id.  The block will be passed an object
      # that responds to read(timeout) with a [message, worker_name] pair or nil if no message is read
      def with_response(message_id, &block)
        raise "Invalid call to read_response for #{@publisher}, not setup for responding" unless @reply_queue
        options = { :destination => @reply_queue, :selector => "JMSCorrelationID = '#{message_id}'" }
        ModernTimes::JMS::Connection.session_pool.consumer(options) do |session, consumer|
          yield MyConsumer.new(consumer)
        end
      end


      #######
      private
      #######

      class MyConsumer
        attr_reader :worker_name

        def initialize(consumer)
          @consumer = consumer
        end

        def read(timeout)
          if timeout > 100
            message = @consumer.receive(leftover_timeout)
          else
            #message = @consumer.receive_no_wait
            message = @consumer.receive(100)
          end
          return nil unless message
          message.acknowledge
          return [ModernTimes::JMS.parse_response(message), message['mt:worker']]
        end
      end
    end
  end
end
