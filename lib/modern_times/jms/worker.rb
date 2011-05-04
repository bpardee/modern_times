require 'benchmark'

module ModernTimes
  module JMS
  
    # Base Worker Class for any class that will be processing messages from topics or queues
    # By default, it will consume messages from a queue with the class name minus the Worker postfix.
    # For example, the queue call is unneccessary as it will default to a value of 'Foo' anyways:
    #  class FooWorker < ModernTimes::JMS::Worker
    #    queue 'Foo'
    #    def perform(obj)
    #      # Perform work on obj
    #    end
    #  end
    #
    # A topic can be specified using virtual_topic as follows (ActiveMQ only).  Multiple separate workers can
    # subscribe to the same topic (under ActiveMQ - see http://activemq.apache.org/virtual-destinations.html):
    #  class FooWorker < ModernTimes::JMS::Worker
    #    virtual_topic 'Zulu'
    #    def perform(obj)
    #      # Perform work on obj
    #    end
    #  end
    #
    # Filters can also be specified within the class:
    #  class FooWorker < ModernTimes::JMS::Worker
    #    filter 'age > 30'
    #    def perform(obj)
    #      # Perform work on obj
    #    end
    #  end
    #
    #
    module Worker
      include ModernTimes::Base::Worker

      attr_reader :session, :message_count
      attr_accessor :message

      module ClassMethods
        def create_supervisor(manager, worker_options)
          Supervisor.new(manager, self, {}, worker_options)
        end

        def marshal(option)
          @marshaler = ModernTimes::MarshalStrategy.find(option)
        end

        def destination_options
          options = dest_options.dup
          # Default the queue name to the Worker name if a destinations hasn't been specified
          if options.keys.select {|k| [:virtual_topic_name, :queue_name, :destination].include?(k)}.empty?
            options[:queue_name] = default_name
          end
          return options
        end

        def virtual_topic(name, opts={})
          # ActiveMQ only
          dest_options[:virtual_topic_name] = name.to_s
        end

        def queue(name, opts={})
          dest_options[:queue_name] = name.to_s
        end

        def dest_options
          @dest_options ||= {}
        end

        def marshaler
          # Default to ruby marshaling, but extenders can override as necessary
          @marshaler ||= ModernTimes::MarshalStrategy::Ruby
        end
      end

      def self.included(base)
        base.extend(ModernTimes::Base::Worker::ClassMethods)
        base.extend(ClassMethods)
      end

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

      def real_destination_options
        options = self.class.destination_options
        virtual_topic_name = options.delete(:virtual_topic_name)
        options[:queue_name] = "Consumer.#{name}.VirtualTopic.#{virtual_topic_name}" if virtual_topic_name
        return options
      end

      # Start the event loop for handling messages off the queue
      def start
        # Grab this to prevent lookup with every message
        @message_marshaler = self.class.marshaler
        @session = Connection.create_consumer_session
        @consumer = @session.consumer(real_destination_options)
        @session.start

        ModernTimes.logger.debug "#{self}: Starting receive loop"
        @status = nil
        while msg = @consumer.receive
          sec = Benchmark.realtime do
            @message_count += 1
            on_message(msg)
            msg.acknowledge
          end
          ModernTimes.logger.info {"#{self}::perform (#{('%.1f' % (sec*1000))}ms)"}
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

      def on_message(message)
        @message = message
        object = @message_marshaler.unmarshal(message.data)
        ModernTimes.logger.debug {"#{self}: Received Object: #{object}"}
        perform(object)
        ModernTimes.logger.debug {"#{self}: Finished processing message"}
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
        "#{real_destination_options.to_a.join('=>')}:#{index}"
      end

      #########
      protected
      #########

      # Create session information and allow extenders to initialize anything necessary prior to the event loop
      def session_init
      end
    end
  end
end