require 'rumx'

module ModernTimes
  class WorkerConfig
    include Rumx::Bean

    attr_reader :name, :timer
    bean_accessor :count, :integer, "Number of workers"

    # Create new WorkerConfig to manage workers of a common class
    def initialize(name, manager, worker_class, options)
      @stopped        = false
      @name           = name
      @manager        = manager
      @worker_class   = worker_class
      @workers        = []
      @worker_mutex   = Mutex.new

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
      if !@timer && count > 0
        @timer = Rumx::TimerBean.new
        bean_add_child('Timer', @timer)
      end
      @worker_mutex.synchronize do
        ModernTimes.logger.info "#{@worker_class.name}: Changing number of workers from #{@workers.size} to #{count}"
        raise "#{@worker_class.name}-#{@name}: Can't change count, this manager has been stopped" if stopped?
        curr_count = @workers.size
        if curr_count < count
          (curr_count...count).each do |index|
            worker = @worker_class.new
            bean_add_child(worker_name(index), worker)
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
            bean_remove_child(worker_name(index))
          end
          @workers = @workers[0, count]
        else
          return
        end
      end
    end

    def stop
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

    private

    def worker_name(index)
      "Worker #{index}"
    end
  end
end
