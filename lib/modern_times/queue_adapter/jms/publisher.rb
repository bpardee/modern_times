# Handle Messaging and Queuing using JMS
module ModernTimes
  module QueueAdapter
    class JMSPublisher

      #attr_reader :persistent, :marshaler, :reply_queue

      def initialize(queue_name, topic_name, options, response_options)
        @dest_options = {:queue_name => queue_name} if queue_name
        @dest_options = {:topic_name => topic_name} if topic_name
        @persistent_sym = options[:persistent] ? :persistent : :non_persistent
        @time_to_live = options[:time_to_live]
        @response_time_to_live_str = response_options[:time_to_live] && response_options[:time_to_live].to_s
        @response_persistent_str = nil
        @response_persistent_str = (!!response_options[:persistent]).to_s unless response_options[:persistent].nil?

        @reply_queue = nil
        if response_options
          ModernTimes::JMS::Connection.session_pool.session do |session|
            @reply_queue = session.create_destination(:queue_name => :temporary)
          end
        end
      end

      def default_marshal_sym
        :ruby
      end

      # Publish the given object and return the message_id.
      def publish(marshaled_object, marshal_sym, marshal_type, props)
        message = nil
        ModernTimes::JMS::Connection.session_pool.producer(@dest_options) do |session, producer|
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

        def read_response(timeout)
          msec = (timeout * 1000).to_i
          if msec > 100
            message = @consumer.receive(msec)
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
