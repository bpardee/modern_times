require 'jms'

# Protocol independent class to handle Publishing
module ModernTimes
  module JMS
    class Publisher
      attr_reader :producer_options, :persistent, :marshaler, :reply_queue

      @@dummy_publishing = false

      # Parameters:
      #   One of the following must be specified
      #     :queue_name            => String: Name of the Queue to publish to
      #     :topic_name            => String: Name of the Topic to publish to (In general this should not be used as all worker threads will receive all messages)
      #     :virtual_topic_name    => String: Name of the Virtual Topic to publish to
      #        (ActiveMQ only, see http://activemq.apache.org/virtual-destinations.html
      #     :destination           => Explicit javax::Jms::Destination to use
      #   Optional:
      #     :time_to_live          => expiration time in ms for the message
      #     :persistent            => true or false (defaults to false)
      #     :marshal               => Symbol: One of :ruby, :string, :json, :bson, :yaml or any registered types (See ModernTimes::MarshalStrategy), defaults to :ruby
      #     :response              => if true, a temporary reply queue will be setup for handling responses (defaults to false unless any other mt_response_* options are set)
      #     :response_time_to_live => expiration time in ms for the response message(s)
      #     :response_persistent   => true or false for the response message(s), set to false if you don't want timed out messages ending up in the DLQ (defaults to true unless mt_response_time_to_live is set)
      def initialize(options)
        raise "ModernTimes::JMS::Connection has not been initialized" unless ModernTimes::JMS::Connection.inited? || @@dummy_publishing
        producer_keys = [:queue_name, :topic_name, :virtual_topic_name, :destination]
        @producer_options = options.reject {|k,v| !producer_keys.include?(k)}
        raise "One of #{producer_keys.join(',')} must be given in #{self.class.name}" if @producer_options.empty?

        # Save our @producer_options for destination comparison when doing dummy_publish,
        # but create the real options by translating virtual_topic_name to a real topic_name.
        @real_producer_options = @producer_options.dup
        virtual_topic_name = @real_producer_options.delete(:virtual_topic_name)
        @real_producer_options[:topic_name] = "VirtualTopic.#{virtual_topic_name}" if virtual_topic_name

        @persistent_sym = options[:persistent] ? :persistent : :non_persistent
        @marshal = options[:marshal] || :ruby
        @marshaler = ModernTimes::MarshalStrategy.find(@marshal)
        @time_to_live = options[:time_to_live]
        @response_time_to_live_str = options[:response_time_to_live] && options[:response_time_to_live].to_s
        @response_persistent_str = nil
        @response_persistent_str = (!!options[:response_persistent]).to_s unless options[:response_persistent].nil?

        @is_response = options[:response] || !@response_time_to_live_str.nil? || !@response_persistent_str.nil?
        @reply_queue = nil
        if !@@dummy_publishing  && @is_response
          ModernTimes::JMS::Connection.session_pool.session do |session|
            @reply_queue = session.create_destination(:queue_name => :temporary)
          end
        end
      end

      def response?
        @is_response
      end

      # Publish the given object to the address.
      def publish(object, props={})
        start = Time.now
        message = nil
        Connection.session_pool.producer(@real_producer_options) do |session, producer|
          producer.time_to_live      = @time_to_live if @time_to_live
          producer.delivery_mode_sym = @persistent_sym
          message = ModernTimes::JMS.create_message(session, @marshaler, object)
          message.jms_reply_to                = @reply_queue if @reply_queue
          message['mt:marshal']               = @marshal.to_s
          message['mt:response:time_to_live'] = @response_time_to_live_str if @response_time_to_live_str
          message['mt:response:persistent']   = @response_persistent_str unless @response_persistent_str.nil?
          props.each do |key, value|
            message.send("#{key}=", value)
          end
          producer.send(message)
        end
        return PublishHandle.new(self, message.jms_message_id, start)
      end

      # For non-configured Rails projects, The above publish method will be overridden to
      # call this publish method instead which calls all the JMS workers that
      # operate on the given address.
      def dummy_publish(object, props={})
        dummy_handle = PublishHandle.new(self, nil, Time.now)
        # Model real queue marshaling/unmarshaling
        trans_object = @marshaler.unmarshal(@marshaler.marshal(object))
        @@workers.each do |worker|
          if ModernTimes::JMS.same_destination?(@producer_options, worker.destination_options)
            if worker.kind_of?(RequestWorker)
              ModernTimes.logger.debug "Dummy request publishing #{trans_object} to #{worker}"
              m = worker.marshaler
              # Model real queue marshaling/unmarshaling
              begin
                response_object = m.unmarshal(m.marshal(worker.request(trans_object)))
                dummy_handle.add_dummy_response(worker.name, response_object)
              rescue Exception => e
                dummy_handle.add_dummy_response(worker.name, ModernTimes::RemoteException.new(e))
              end
            elsif worker.kind_of?(Worker)
              ModernTimes.logger.debug "Dummy publishing #{trans_object} to #{worker}"
              begin
                worker.perform(trans_object)
              rescue Exception => e
                ModernTimes.logger.error("#{worker} Exception: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
              end
            end
          end
        end
        return dummy_handle
      end

      def to_s
        "#{self.class.name}:#{@real_producer_options.inspect}"
      end

      def self.setup_dummy_publishing(workers)
        @@dummy_publishing = true
        @@workers = workers
        alias_method :real_publish, :publish
        alias_method :publish, :dummy_publish
        PublishHandle.setup_dummy_handling
      end

      # For testing
      def self.clear_dummy_publishing
        @@dummy_publishing = false
        alias_method :dummy_publish, :publish
        alias_method :publish, :real_publish
        #remove_method :real_publish
        PublishHandle.clear_dummy_handling
      end
    end
  end
end