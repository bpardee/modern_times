require 'hornetq'

# Handle Messaging and Queuing
module ModernTimes
  module HornetQ
    module Client
      # Singleton-ize
      extend self

      # Initialize the messaging system and connection pool for this VM
      def init(config)
        @config = config
        @connection = ::HornetQ::Client::Connection.new(@config[:connection])
        # Let's not create a session_pool unless we're going to use it
        @session_pool_mutex = Mutex.new

        at_exit do
          close
        end
      end

      def invm?
        @connection.invm?
      end

      # Create a session targeted for a consumer (producers should use the session_pool)
      def create_consumer_session
        @connection.create_session(config[:session])
      end

      def session_pool
        # Don't use the mutex unless we have to!
        return @session_pool if @session_pool
        @session_pool_mutex.synchronize do
          # if it's been created in between the above call and now, return it
          return @session_pool if @session_pool
          return @session_pool = @connection.create_session_pool(config[:session])
        end
      end

      def close
        ModernTimes.logger.info "Closing #{self.name}"
        @session_pool.close if @session_pool
        @connection.close if @connection
      end

      def config
        raise "#{self.name} never had it's init method called" unless @config
        @config
      end
    end
  end
end