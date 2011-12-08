require 'rumx'
require 'gene_pool'

module ModernTimes
  class WorkerConfig
    include Rumx::Bean

    attr_reader        :name, :marshal_type, :marshaler
    # The adapter refers to the corresponding class in ModernTimes::QueueAdapter::<type>::WorkerConfig
    attr_reader        :adapter

    bean_reader        :count,        :integer, 'Current number of workers'
    bean_attr_accessor :max_count,    :integer, 'Max number of workers allowed', :config_item => true
    bean_attr_accessor :warn_timeout, :float,   'Idle timeout where a warning message will be logged if unable to acquire a worker (i.e., all workers are currently busy)', :config_item => true
    bean_attr_embed    :adapter,                'Adapter for worker queue interface'
    bean_attr_embed    :timer,                  'Track the times for this worker'

    # Create new WorkerConfig to manage workers of a common class
    def initialize(name, manager, worker_class, options)
      @status         = 'Idle'
      @warn_timeout   = 0.25
      @stopped        = false
      @max_count      = 0
      @name           = name
      @index_count    = 0
      @index_mutex    = Mutex.new
      @manager        = manager
      @worker_class   = worker_class
      @read_mutex     = Mutex.new
      @read_condition = ConditionVariable.new
      response_options = worker_class.queue_options[:response] || {}
      @adapter        = QueueAdapter.create_worker_config(self, worker_class.queue_name(@name), worker_class.topic_name, worker_class.queue_options, response_options)
      # Defines how we will marshal the response
      @marshal_type = (response_options[:marshal] || @adapter.default_marshal_type).to_s
      @marshaler    = MarshalStrategy.find(@marshal_type)

      #ModernTimes.logger.debug { "options=#{options.inspect}" }
      options.each do |key, value|
        begin
          send(key.to_s+'=', value)
        rescue Exception => e
          ModernTimes.logger.warn "WARNING: During initialization of #{worker_class.name} config=#{@name}, assignment of #{key}=#{value} was invalid"
        end
      end
    end

    def count
      return 0 unless @gene_pool
      @gene_pool.size
    end

    def warn_timeout=(value)
      @warn_timeout = value
      @gene_pool.warn_timeout = value if @gene_pool
    end

    def max_count=(new_max_count)
      return if @max_count == new_max_count
      raise "#{@worker_class.name}-#{@name}: Can't change count since we've been stopped" if @stopped
      @read_mutex.synchronize do
        if new_max_count > 0
          ModernTimes.logger.info "#{@worker_class.name}: Changing max number of workers from #{@max_count} to #{new_max_count}"
          @timer ||= Rumx::Beans::Timer.new
          if !@gene_pool
            @gene_pool = GenePool.new(:name         => "#{@manager.name}: #{@name}",
                                      :pool_size    => new_max_count,
                                      :warn_timeout => @warn_timeout,
                                      :close_proc   => :stop,
                                      :logger       => ModernTimes.logger) do
              worker = @worker_class.new
              worker.start(@index_count, self)
              @index_mutex.synchronize { @index_count += 1 }
              worker
            end
            event_loop
          else
            # TODO: We should probably do a check for max_count == 0 and remove the gene_pool? Check in-mem adapter and dropping of messages
            @gene_pool.pool_size = new_max_count
          end
        end
      end
      @max_count = new_max_count
    end

    def message_read_complete(worker)
      #puts "#{self}: got message_read_complete from #{worker}"
      @read_mutex.synchronize do
        @read_condition.signal
      end
    end

    def message_processing_complete(worker)
      #puts "#{self}: got message_processing_complete from #{worker}"
      @gene_pool.checkin(worker)
    end

    def stop
      # First stop the adapter.  For InMem, this will not return until all the messages in the queue have
      # been processed since these messages are not persistent.
      @adapter.stop
      @read_mutex.synchronize do
        @gene_pool.close if @gene_pool
        @stopped = true
      end
    end

    def worker_stopped(worker)
      @gene_pool.remove(worker)
    end

    # Override rumx bean method
    def bean_attributes_changed
      super
      @manager.save_persist_state
    end

    def marshal_response(object)
      @marshaler.marshal(object)
    end

    def unmarshal_response(marshaled_object)
      @marshaler.unmarshal(marshaled_object)
    end

    def to_s
      @name
    end

    private

    def event_loop
      # The requirements are to expand and contract the worker pool as necessary.  Thus, we want to create a new worker
      # when there is potentially a message available on the queue and all of the current workers are still processing their message.
      # From a JMS perspective, we want to read the message, process it and then acknowledge it within the same thread.
      # (I'm pretty sure this is correct in that we have to acknowledge the message in the same thread (JMS Consumer) that read it?
      # although this is probably a reasonable requirement for providing a ZeroMQ adapter also)
      # Therefore, we want to acquire a worker (via gene_pool which handles contracting/expanding).  We tell that worker
      # that it can read a message (Worker#ok_to_read).  It reads the message in it's working thread and signals back (message_read_complete) that it has read the
      # message.  Since this is occurring in it's worker thread, we have to signal our event thread (this method) that
      # the worker has read a message and it can acquire a new worker.   In the worker's thread, it processes the message,
      # acknowledges it and signals that is done and ready for a new message (message_processing_complete) so that we
      # can release the worker to the gene_pool.
      @status         = 'Started'
      @stopped        = false

      ModernTimes.logger.debug "#{self}: Starting receive loop"
      @event_loop_thread = Thread.new do
        begin
          while !@stopped
            #puts "#{self}: Waiting for worker checkout"
            worker = @gene_pool.checkout
            #puts "#{self}: Done waiting for worker checkout #{worker}"
            worker.ok_to_read
            @read_mutex.synchronize do
              #puts "#{self}: Waiting for read complete"
              @read_condition.wait(@read_mutex)
              #puts "#{self}: Done waiting for read complete"
            end
          end
          @status = 'Stopped'
          ModernTimes.logger.info "#{self}: Exiting event loop"
        rescue Exception => e
          @status = "Terminated: #{e.message}"
          ModernTimes.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
        ensure
          ModernTimes.logger.flush if ModernTimes.logger.respond_to?(:flush)
        end
      end
    end
  end
end
