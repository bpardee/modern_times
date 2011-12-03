require 'rumx'

module ModernTimes
  class WorkerConfig
    include Rumx::Bean

    attr_reader          :name, :adapter
    bean_attr_embed      :timer,           'Track the times for this worker'
    bean_attr_embed_list :workers,         'The worker threads'
    bean_accessor        :count, :integer, 'Number of workers', :config_item => true
    bean_attr_embed      :adapter,         'Adapter for worker queue interface'

    # Create new WorkerConfig to manage workers of a common class
    def initialize(name, manager, worker_class, options)
      @stopped        = false
      @name           = name
      @manager        = manager
      @worker_class   = worker_class
      @workers        = []
      @worker_mutex   = Mutex.new
      @adapter        = QueueAdapter.create_worker(self, worker_class.queue_name(@name), worker_class.topic_name, worker_class.queue_options, worker_class.queue_options[:response] || {})

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
      @workers.size
    end

    def count=(count)
      @worker_mutex.synchronize do
        @timer ||= Rumx::Beans::Timer.new if count > 0
        ModernTimes.logger.info "#{@worker_class.name}: Changing number of workers from #{@workers.size} to #{count}"
        raise "#{@worker_class.name}-#{@name}: Can't change count, this manager has been stopped" if stopped?
        curr_count = @workers.size
        if curr_count < count
          (curr_count...count).each do |index|
            worker = @worker_class.new
            worker.index  = index
            worker.config = self
            worker.thread = Thread.new do
              java.lang.Thread.current_thread.name = "ModernTimes worker: #{worker}"
              #ModernTimes.logger.debug "#{worker}: Started thread with priority #{Thread.current.priority}"
              worker.start
            end
            @workers << worker
          end
        elsif curr_count > count
          (count...curr_count).each { |index| @workers[index].stop }
          (count...curr_count).each do |index|
            @workers[index].thread.join
          end
          @workers = @workers[0, count]
        else
          return
        end
      end
    end

    def stop
      @adapter.close
      @worker_mutex.synchronize do
        @stopped = true
        @workers.each { |worker| worker.stop }
      end
    end

    def stopped?
      @stopped
    end

    def join
      @workers.each { |worker| worker.join }
    end

    # Override rumx bean method
    def bean_attributes_changed
      super
      @manager.save_persist_state
    end
  end
end
