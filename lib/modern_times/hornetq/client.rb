require 'hornetq'

# Protocol independent class to handle Messaging and Queuing
module ModernTimes
  module HornetQ
    module Client
      # Singleton-ize
      extend self

      # Initialize the messaging system and connection pool for this VM
      def init(config)
        @config = config
        @connection = ::HornetQ::Client::Connection.new(@config[:connection])
        @session_pool_mutex = Mutex.new

        # TODO:
  #        # Need to start the HornetQ Server in this VM
  #        if server_cfg = cfg[:server]
  #          @@server = HornetQ::Server.create_server(server_cfg)
  #          @@server.start
  #
  #          # TODO: Should add check that host given to server is invm
  #          #if @@server.host == 'invm'
  #            # Handle messages within this process
  #            @@manager = Messaging::WorkerManager.new
  #            @@manager.start
  #          #end
  #        end

        at_exit do
          close
        end
      end

      # Create a session targeted for a consumer (producers should use the session_pool)
      def create_consumer_session
        @connection.create_session(@config[:session])
      end

      def session_pool
        # Don't use the mutex unless we have to!
        return @session_pool if @session_pool
        @session_pool_mutex.synchronize do
          # if it's been created in between the above call and now, return it
          return @session_pool if @session_pool
          return @session_pool = @connection.create_session_pool(@config[:session])
        end
      end

      # Publish the given object to the address.  For non-configured rails projects, this
      # method will be overridden in DummyPublisher.
      def publish(address, object)
        # TODO: Possible performance enhancements on producer
        # setDisableMessageID()
        # setDisableMessageTimeStamp()
        # See http://hornetq.sourceforge.net/docs/hornetq-2.1.2.Final/user-manual/en/html/perf-tuning.html
        session_pool.producer(address) do |session, producer|
          message = Marshal.marshal(session, object)
          first_time = true
          begin
            producer.send(message)
          rescue Java::org.hornetq.api.core.HornetQException => e
            Rails.logger.warn "Received producer exception: #{e.message} with code=#{e.cause.code}"
            if first_time && e.cause.code == Java::org.hornetq.api.core.HornetQException::UNBLOCKED
              Rails.logger.info "Retrying the send"
              first_time = false
              retry
            else
              raise
            end
          end
        end
      end

      def close
        ModernTimes.logger.info "Closing #{self.name}"
        @session_pool.close if @session_pool
        @connection.close if @connection
        #@server.stop if @@server
      end
    end
  end
end