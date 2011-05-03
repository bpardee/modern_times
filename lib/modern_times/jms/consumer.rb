require 'jms'

# Protocol independent class to handle Publishing
module ModernTimes
  module JMS
    class Consumer
      attr_reader :consumer_options, :persistent, :marshaler

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
        consumer_keys = [:queue_name, :topic_name, :virtual_topic_name, :destination]
        @consumer_options = options.reject {|k,v| !consumer_keys.include?(k)}
        raise "One of #{consumer_keys.join(',')} must be given in #{self.class.name}" if @consumer_options.empty?

        # Save our @consumer_options for destination comparison when doing dummy_publish,
        # but create the real options by translating virtual_topic_name to a real topic_name.
        @real_consumer_options = @consumer_options.dup
        virtual_topic_name = @real_consumer_options.delete(:virtual_topic_name)
        @real_consumer_options[:topic_name] = "VirtualTopic.#{virtual_topic_name}" if virtual_topic_name
        @marshaler = ModernTimes::MarshalStrategy.find(options[:marshal])
      end

      # Publish the given object to the address.
      def receive(options={})
        options = @real_consumer_options.merge(options)
        correlation_id = options.delete(:jms_correlation_id)
        options[:selector] = "JMSCorrelationID = '#{correlation_id}'" if correlation_id && !options[:selector]
        timeout = options.delete(:timeout) || 0
        obj = nil

        Connection.session_pool.consumer(options) do |session, consumer|
          message = consumer.get(:timeout => timeout)
          obj = @marshaler.unmarshal(message.data) if message
        end
        return obj
      end

      # For non-configured Rails projects, The above publish method will be overridden to
      # call this publish method instead which calls all the JMS workers that
      # operate on the given address.
      def dummy_receive(options={})
        if correlation_id = options.delete(:jms_correlation_id)
          return Publisher.dummy_cache(correlation_id)
        else
          # TODO: Pop off if no correlation id given
        end
      end

      def to_s
        "#{self.class.name}:#{@real_consumer_options.inspect}"
      end

      def self.setup_dummy_receiving
        alias_method :real_receive, :receive
        alias_method :receive, :dummy_receive
      end

      # For testing
      def self.clear_dummy_receiving
        alias_method :dummy_receive, :receive
        alias_method :receive, :real_receive
        #remove_method :real_receive
      end
    end
  end
end
