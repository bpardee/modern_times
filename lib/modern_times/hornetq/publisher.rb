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

      # Publish the given object to the address.  For non-configured rails projects, this
      # method will be overridden by DummyPublisher.
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
    end
  end
end