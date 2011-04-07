module ModernTimes
  module JMS
  
    # Base Worker Class for any class that will be processing messages from topics or queues
    # By default, it will consume messages from a queue with the class name minus the Worker postfix.
    # For example, the queue_name call is unneccessary as it will default to a value of 'Foo' anyways:
    # class FooWorker < ModernTimes::JMS::Worker
    #   queue_name 'Foo'
    #   def perform(obj)
    #     # Perform work on obj
    #   end
    # end
    #
    # A topic can be specified as followed.  Multiple separate workers can subscribe to the same topic:
    # class FooWorker < ModernTimes::JMS::Worker
    #   topic_name 'Zulu'
    #   def perform(obj)
    #     # Perform work on obj
    #   end
    # end
    #
    # Filters can also be specified within the class:
    # class FooWorker < ModernTimes::JMS::Worker
    #   filter 'age > 30'
    #   def perform(obj)
    #     # Perform work on obj
    #   end
    # end
    #
    #
    class Worker < ModernTimes::Base::Worker
      # Default to ruby marshaling, but extenders can override as necessary
      include ModernTimes::MarshalStrategy::Ruby

      # Make JMS::Supervisor our supervisor
      supervisor Supervisor
      
      attr_reader :session, :message_count

      def initialize(opts={})
        super
        @status = 'initialized'
        @message_count = 0
      end

      def setup
      end

      def status
        @status || "Processing message #{message_count}"
      end

      def on_message(message)
        object = unmarshal(message.data)
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

      def to_s
        "#{@options.to_a.join('=>')}:#{index}"
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
        ModernTimes.logger.info "#{self}: Exiting"
      rescue javax.jms.IllegalStateException => e
        #if e.cause.code == Java::org.jms.api.core.JMSException::OBJECT_CLOSED
          # Normal exit
          @status = 'Exited'
          ModernTimes.logger.info "#{self}: Exiting due to close"
        #else
        #  @status = "Exited with JMS exception #{e.message}"
        #  ModernTImes.logger.error "#{self} JMSException: #{e.message}\n#{e.backtrace.join("\n")}"
        #end
      rescue Exception => e
        @status = "Exited with exception #{e.message}"
        ModernTimes.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      rescue java.lang.Exception => e
        @status = "Exited with java exception #{e.message}"
        ModernTimes.logger.error "#{self}: Java exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      end

      def stop
        @consumer.close if @consumer
        @session.close if @session
      end

      #########
      protected
      #########

      # Create session information and allow extenders to initialize anything necessary prior to the event loop
      def session_init
        @options = self.class.default_options.dup
        # Default the queue name to the Worker name if a destinations hasn't been specified
        if @options.keys.select {|k| [:topic_name, :queue_name, :destination].include?(k)}.empty?
          @options[:queue_name] = self.class.default_name
        end
        @session = Connection.create_consumer_session
        @consumer = @session.consumer(@options)
        @session.start
      end

      def self.default_options
        @default_options ||= {}
      end

      def self.topic_name(name)
        default_options[:topic_name] = name.to_s
      end

      def self.queue_name(name)
        default_options[:queue_name] = name.to_s
      end
    end
  end
end