require 'jms'

# Handle Messaging and Queuing
module ModernTimes
  module JMS
    module Connection
      # Singleton-ize
      extend self

      # Initialize the messaging system and connection pool for this VM
      def init(config)
        @config = config
        @inited = true
        @connection = ::JMS::Connection.new(config)
        @connection.start
        # Let's not create a session_pool unless we're going to use it
        @session_pool_mutex = Mutex.new

        at_exit do
          close
        end
      end

      def inited?
        @inited
      end

      # Create a session targeted for a consumer (producers should use the session_pool)
      def create_consumer_session
        connection.create_session(@config || {})
      end

      def session_pool
        # Don't use the mutex unless we have to!
        return @session_pool if @session_pool
        @session_pool_mutex.synchronize do
          # if it's been created in between the above call and now, return it
          return @session_pool if @session_pool
          return @session_pool = connection.create_session_pool(@config)
        end
      end

      def close
        return if @closed
        ModernTimes.logger.info "Closing #{self.name}"
        @session_pool.close if @session_pool
        if @connection
          @connection.stop
          @connection.close
        end
        @closed = true
      end

      def connection
        raise "#{self.name} never had it's init method called" unless @connection
        @connection
      end
    end
  end
end