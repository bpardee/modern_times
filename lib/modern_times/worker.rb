module ModernTimes

  # Base Worker Class for any class that will be processing messages from topics or queues
  # By default, it will consume messages from a queue with the class name minus the Worker postfix.
  # For example, the queue call is unnecessary as it will default to a value of 'Foo' anyways:
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
  # TODO (maybe):
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
    include ModernTimes::BaseWorker

    attr_accessor :message, :adapter
    attr_reader   :status

    module ClassMethods
      def queue(name, opts={})
        # If we're using the default name but we still want to set queue options, then a name won't be given.
        if name.kind_of?(Hash)
          @queue_options = name
        else
          @queue_name = name.to_s
          @queue_options = opts
        end
      end

      def topic(name, options={})
        @topic_name = name.to_s
        @queue_options = opts
      end

      # Set the fail_queue
      # target =>
      #   boolean
      #     true - exceptions in the worker will cause the message to be forwarded to the queue of <default-name>Fail
      #       For instance, an Exception in FooWorker#perform will forward the message to the queue FooFail
      #     false - exceptions will not result in the message being forwarded to a fail queue
      #   string - equivalent to true but the string defines the name of the fail queue
      def fail_queue(target, opts={})
        @fail_queue_target = target
      end

      def fail_queue_target
        @fail_queue_target
      end

      # Defines the default value of the fail_queue_target.  For extenders of this class, the default will be true
      # but extenders can change this (RequestWorker returns exceptions to the caller so it defaults to false).
      def default_fail_queue_target
        true
      end

      def queue_name(default_name)
        return @queue_name if @queue_name
        return nil if @otopic_name
        return default_name
      end

      def topic_name
        @topic_name
      end

      def queue_options
        @queue_options ||= {}
      end

      def fail_queue_name(worker_config)
        # TBD - Set up fail_queue as a config
        target = self.class.fail_queue_target
        # Don't overwrite if the user set to false, only if it was never set
        target = self.class.default_fail_queue_target if target.nil?
        if target == true
          return "#{config.name}Fail"
        elsif target == false
          return nil
        elsif target.kind_of?(String)
          return target
        else
          raise "Invalid fail queue: #{target}"
        end
      end
    end

    def self.included(base)
      ModernTimes::BaseWorker.included(base)
      base.extend(ClassMethods)
    end

    def start(index, worker_config)
      @status               = 'Started'
      @stopped              = false
      @read_mutex           = Mutex.new
      @read_condition       = ConditionVariable.new
      @processing_mutex     = Mutex.new
      @processing_condition = ConditionVariable.new
      @ok_to_read           = false
      self.index  = index
      self.config = worker_config
      self.adapter = worker_config.adapter.create_worker
      self.thread = Thread.new do
        java.lang.Thread.current_thread.name = "ModernTimes worker: #{self}"
        #ModernTimes.logger.debug "#{worker}: Started thread with priority #{Thread.current.priority}"
        event_loop
      end
    end

    def ok_to_read
      #puts "#{self}: got ok_to_read"
      @read_mutex.synchronize do
        @ok_to_read = true
        @read_condition.signal
      end
      #puts "#{self}: done ok_to_read"
    end

    # Workers will be starting and stopping on an as needed basis.  Thus, when they get a stop command they should
    # clean up any resources.  We don't want to clobber resources while a message is being processed so processing_mutex will surround
    # message processessing and worker closing.
    # From a JMS perspective, stop all workers (close consumer and session), stop the config.
    # From an InMem perspective, we don't want the workers stopping until all messages in the queue have been processed.
    # Therefore we want to stop the
    def stop
      @status  = 'Stopping'
      @stopped = true
      @read_mutex.synchronize do
        @read_condition.signal
      end
      # Don't clobber adapter resources until we're finished processing the current message
      @processing_mutex.synchronize do
        # This should interrupt @adapter.receive_message above and cause it to return nil
        @adapter.close
      end
    end

    # Allow extends to clean up any resources associated with this worker
    def close
    end

    def perform(object)
      raise "#{self}: Need to override perform method in #{self.class.name} in order to act on #{object}"
    end

    def to_s
      "#{config.name}:#{index}"
    end

    def log_backtrace(e)
      ModernTimes.logger.error "\t#{e.backtrace.join("\n\t")}"
    end

    #########
    protected
    #########

    # Start the event loop for handling messages off the queue
    def event_loop
      ModernTimes.logger.debug "#{self}: Starting receive loop"
      while !@stopped && !config.adapter.stopped
        @read_mutex.synchronize do
          #puts "#{self}: Waiting for next available read"
          @read_condition.wait(@read_mutex) unless @stopped || @ok_to_read
          #puts "#{self}: Done waiting for next available read"
          if !@stopped && @ok_to_read
            @ok_to_read = false
            puts "#{self}: Waiting for next adapter read"
            msg = @adapter.receive_message
            puts "#{self}: Done waiting for next adapter read"
            if msg
              config.message_read_complete(self)
              delta = config.timer.measure do
                @processing_mutex.synchronize do
                  on_message(msg)
                  @adapter.acknowledge_message(msg)
                end
              end
              config.message_processing_complete(self)
              ModernTimes.logger.info {"#{self}::on_message (#{'%.1f' % delta}ms)"} if ModernTimes::JMS::Connection.log_times?
              ModernTimes.logger.flush if ModernTimes.logger.respond_to?(:flush)
            end
          end
        end
      end
      @status = 'Stopped'
      ModernTimes.logger.info "#{self}: Exiting"
    rescue Exception => e
      @status = "Terminated: #{e.message}"
      ModernTimes.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    ensure
      ModernTimes.logger.flush if ModernTimes.logger.respond_to?(:flush)
      config.worker_stopped(self)
      close
    end

    def on_message(message)
      # TBD - Is it necessary to provide underlying message to worker?  Should we generically provide access to message attributes?  Do filters somehow fit in here?
      @message = message
      object = @adapter.message_to_object(message)
      ModernTimes.logger.debug {"#{self}: Received Object: #{object}"}
      perform(object)
    rescue Exception => e
      on_exception(e)
    ensure
      ModernTimes.logger.debug {"#{self}: Finished processing message"}
    end

    def on_exception(e)
      ModernTimes.logger.error "#{self}: Messaging Exception: #{e.message}"
      log_backtrace(e)
      @adapter.handle_failure(message, @fail_queue_name) if @fail_queue_name
    rescue Exception => e
      ModernTimes.logger.error "#{self}: Exception in exception reply: #{e.message}"
      log_backtrace(e)
    end

    def fail_queue_name
      @fail_queue_name
    end
  end
end
