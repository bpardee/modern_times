require 'hornetq'

# Protocol independent class to handle Publishing
module ModernTimes
  module HornetQ
    class Publisher

      # TODO: Possible performance enhancements on producer
      # setDisableMessageID()
      # setDisableMessageTimeStamp()
      # See http://hornetq.sourceforge.net/docs/hornetq-2.1.2.Final/user-manual/en/html/perf-tuning.html
      # Create producer pool as per above section 46.6?
      def initialize(address, options={})
        @address = address
        @durable = !!options[:durable]
        if options[:marshal].nil?
          marshal_module = MarshalStrategy::Ruby
        elsif options[:marshal].kind_of? Symbol
          marshal_module = case options[:marshal]
                             when :ruby   then MarshalStrategy::Ruby
                             when :string then MarshalStrategy::String
                             when :json   then MarshalStrategy::JSON
                             else raise "Invalid marshal strategy: #{options[:marshal]}"
                           end
        elsif options[:marshal].kind_of? Module
          marshal_module = options[:marshal]
        else
          raise "Invalid marshal strategy: #{options[:marshal]}"
        end
        self.extend marshal_module
      end

      # Publish the given object to the address.
      def publish(object)
        Client.session_pool.producer(@address) do |session, producer|
          message = marshal(session, object, @durable)
          first_time = true
          begin
            producer.send(message)
          rescue Java::org.hornetq.api.core.HornetQException => e
            ModernTimes.logger.warn "Received producer exception: #{e.message} with code=#{e.cause.code}"
            if first_time && e.cause.code == Java::org.hornetq.api.core.HornetQException::UNBLOCKED
              ModernTimes.logger.info "Retrying the send"
              first_time = false
              retry
            else
              raise
            end
          end
        end
      end

      # For non-configured Rails projects, The above publish method will be overridden to
      # call this publish method instead which calls all the HornetQ workers that
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