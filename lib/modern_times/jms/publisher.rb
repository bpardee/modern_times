require 'jms'

# Protocol independent class to handle Publishing
module ModernTimes
  module JMS
    class Publisher

      # Parameters:
      #   One of the following must be specified
      #     :queue_name => String: Name of the Queue to publish to
      #     :topic_name => String: Name of the Topic to publish to
      #     :destination=> Explicit javaxJms::Destination to use
      #   Optional:
      #     :persistent => true or false (defaults to false)
      #     :marshal    => Symbol: One of :ruby, :string, or :json
      #                 => Module: Module that defines marshal and unmarshal method
      def initialize(options)
        producer_keys = [:queue_name, :topic_name, :destination]
        @producer_options = options.reject {|k,v| !producer_keys.include?(k)}
        raise "One of #{producer_keys.join(',')} must be given in #{self.class.name}" if @producer_options.empty?
        @persistent = options[:persistent] ? javax.jms.DeliveryMode::PERSISTENT : javax.jms.DeliveryMode::NON_PERSISTENT
        marshal = options[:marshal]
        if marshal.nil?
          marshal_module = ModernTimes::MarshalStrategy::Ruby
        elsif marshal.kind_of? Symbol
          marshal_module = case marshal
                             when :ruby   then ModernTimes::MarshalStrategy::Ruby
                             when :string then ModernTimes::MarshalStrategy::String
                             when :json   then ModernTimes::MarshalStrategy::JSON
                             else raise "Invalid marshal strategy: #{options[:marshal]}"
                           end
        elsif marshal.kind_of? Module
          marshal_module = marshal
        else
          raise "Invalid marshal strategy: #{marshal}"
        end
        self.extend marshal_module
      end

      # Publish the given object to the address.
      def publish(object, props={})
        message = nil
        Connection.session_pool.producer(@producer_options) do |session, producer|
          message = session.message(marshal(object))
          message.jms_delivery_mode = @persistent
          props.each do |key, value|
            message.send("#{key}=", value)
          end
          # TODO: Is send_with_retry possible?
          #producer.send_with_retry(message)
          producer.send(message)
        end
        return message
      end

      # For non-configured Rails projects, The above publish method will be overridden to
      # call this publish method instead which calls all the JMS workers that
      # operate on the given address.
      def dummy_publish(object)
        @@worker_instances.each do |worker|
          if worker.kind_of?(Worker) && worker.address_name == @address
            ModernTimes.logger.debug "Dummy publishing #{object} to #{worker}"
            worker.perform(object)
          end
        end
      end

      def self.setup_dummy_publishing(workers)
        @@worker_instances = workers.map {|worker| worker.new}
        alias_method :real_publish, :publish
        alias_method :publish, :dummy_publish
      end
    end
  end
end