module ModernTimes
  module HornetQ
  
    # Base Worker Class for any class that will be processing messages from queues
    class Worker < ModernTimes::Base::Worker
      # Default to ruby marshaling, but extenders can override as necessary
      include MarshalStrategy::Ruby

      # Make HornetQ::Supervisor our supervisor
      supervisor Supervisor
      
      attr_reader :session, :message_count

      def initialize(opts={})
        super
        @status = 'initialized'
        @message_count = 0
      end

      def setup
        session = Client.create_consumer_session
        session.create_queue_ignore_exists(address_name, queue_name, false)
        session.close
      end

      def status
        @status || "Processing message #{message_count}"
      end

      def on_message(message)
        object = unmarshal(message)
        ModernTimes.logger.debug "#{self}: Received Object: #{object}" if ModernTimes.logger.debug?
        perform(object)
        ModernTimes.logger.debug "#{self}: Finished processing message" if ModernTimes.logger.debug?
        ModernTimes.logger.flush if ModernTimes.logger.respond_to?(:flush)
      rescue Exception => e
        ModernTimes.logger.error "#{self}: Messaging Exception: #{e.inspect}\n#{e.backtrace.inspect}"
      rescue java.lang.Exception => e
        ModernTimes.logger.error "#{self}: Java Messaging Exception: #{e.inspect}\n#{e.backtrace.inspect}"
      end

      def perform(object)
        raise "#{self}: Need to override perform method in #{self.class.name} in order to act on #{object}"
      end

      def self.address_name
        @address_name ||= default_name
      end

      def self.queue_name
        @queue_name ||= default_name
      end

      def address_name
        self.class.address_name
      end

      def queue_name
        self.class.queue_name
      end

      def to_s
        "#{address_name}:#{queue_name}:#{index}"
      end

      # Start the event loop for handling messages off the queue
      def start
        session_init
        ModernTimes.logger.debug "#{self}: Starting receive loop"
        @status = nil
        while msg = @consumer.receive
          @message_count += 1
          supervisor.incr_message_count
          on_message(msg)
          msg.acknowledge
        end
        @status = 'Exited'
        ModernTimes.logger.info "Exiting #{self}"
      rescue Java::org.hornetq.api.core.HornetQException => e
        if e.cause.code == Java::org.hornetq.api.core.HornetQException::OBJECT_CLOSED
          # Normal exit
          @status = 'Exited'
          ModernTimes.logger.info "#{self}: Exiting due to close"
        else
          @status = "Exited with HornetQ exception #{e.message}"
          ModernTImes.logger.error "#{self} HornetQException: #{e.message}\n#{e.backtrace.join("\n")}"
        end
      rescue Exception => e
        @status = "Exited with exception #{e.message}"
        ModernTimes.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      rescue java.lang.Exception => e
        @status = "Exited with java exception #{e.message}"
        ModernTimes.logger.error "#{self}: Java exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      end

      def stop
        @session.close if @session
      end

      #########
      protected
      #########

      # Create session information and allow extenders to initialize anything necessary prior to the event loop
      def session_init
        @session = Client.create_consumer_session
        @consumer = @session.create_consumer(queue_name)
        @session.start
      end

      # Create a queue, assigned to the specified address
      # Every time a message arrives, the perform instance method
      # will be called. The parameter to the method is the Ruby
      # object supplied when the message was sent
      def self.address(address_name, opts={})
        @address_name = address_name.to_s
        #Messaging::Client.on_message(address, queue_name) do |object|
        #  self.send(method.to_sym, object)
        #end
      end

      def self.queue(queue_name, opts={})
        @queue_name = queue_name.to_s
      end
    end
  end
end