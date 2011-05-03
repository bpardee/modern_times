require 'jms'

# Protocol independent class to handle Publishing
module ModernTimes
  module JMS
    class Publisher
      attr_reader :producer_options, :persistent, :marshaler

      # Parameters:
      #   One of the following must be specified
      #     :queue_name => String: Name of the Queue to publish to
      #     :topic_name => String: Name of the Topic to publish to
      #     :virtual_topic_name => String: Name of the Virtual Topic to publish to
      #        (ActiveMQ only, see http://activemq.apache.org/virtual-destinations.html
      #     :destination=> Explicit javax::Jms::Destination to use
      #   Optional:
      #     :persistent => true or false (defaults to false)
      #     :marshal    => Symbol: One of :ruby, :string, or :json
      #                 => Module: Module that defines marshal and unmarshal method
      def initialize(options)
        producer_keys = [:queue_name, :topic_name, :virtual_topic_name, :destination]
        @producer_options = options.reject {|k,v| !producer_keys.include?(k)}
        raise "One of #{producer_keys.join(',')} must be given in #{self.class.name}" if @producer_options.empty?

        # Save our @producer_options for destination comparison when doing dummy_publish,
        # but create the real options by translating virtual_topic_name to a real topic_name.
        @real_producer_options = @producer_options.dup
        virtual_topic_name = @real_producer_options.delete(:virtual_topic_name)
        @real_producer_options[:topic_name] = "VirtualTopic.#{virtual_topic_name}" if virtual_topic_name

        # If we're in dummy mode, this probably won't be defined
        #@persistent = options[:persistent] ? ::JMS::DeliveryMode::PERSISTENT : ::JMS::DeliveryMode::NON_PERSISTENT
        @persistent = options[:persistent] ? :persistent : :non_persistent
        @marshaler = ModernTimes::MarshalStrategy.find(options[:marshal])
      end

      # Publish the given object to the address.
      def publish(object, props={})
        message = nil
        Connection.session_pool.producer(@real_producer_options) do |session, producer|
          message = ModernTimes::JMS.create_message(session, @marshaler, object)
          message.jms_delivery_mode_sym = @persistent
          props.each do |key, value|
            message.send("#{key}=", value)
          end
          # TODO: Is send_with_retry possible?
          #producer.send_with_retry(message)
          producer.send(message)
        end
        return message.jms_message_id
      end

      # For non-configured Rails projects, The above publish method will be overridden to
      # call this publish method instead which calls all the JMS workers that
      # operate on the given address.
      def dummy_publish(object, props={})
        @@message_id += 1
        @@worker_instances.each do |worker|
          if worker.kind_of?(Worker) && ModernTimes::JMS.same_destination?(@producer_options, worker.class.destination_options)
            ModernTimes.logger.debug "Dummy publishing #{object} to #{worker}"
            worker.message = OpenStruct.new(:jms_message_id => @@message_id.to_s)
            worker.perform(object)
          end
        end
        if correlation_id = props[:jms_correlation_id]
          @@dummy_cache[correlation_id] = object
        end
        return @@message_id.to_s
      end

      def to_s
        "#{self.class.name}:#{@real_producer_options.inspect}"
      end

      def self.setup_dummy_publishing(workers)
        require 'ostruct'
        @@message_id = 0
        @@dummy_cache = {}
        @@worker_instances = workers.map {|worker| worker.new}
        alias_method :real_publish, :publish
        alias_method :publish, :dummy_publish
      end

      # For testing
      def self.clear_dummy_publishing
        alias_method :dummy_publish, :publish
        alias_method :publish, :real_publish
        #remove_method :real_publish
      end

      def self.dummy_cache(correlation_id)
        @@dummy_cache.delete(correlation_id)
      end
    end
  end
end