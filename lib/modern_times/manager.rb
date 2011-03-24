module ModernTimes
  class Manager
    attr_accessor :allowed_workers

    def initialize(config={})
      @stopped = false
      @config = config
      @domain = config[:domain] || 'ModernTimes'
      @supervisors = []
      @jmx_server = JMX::MBeanServer.new
      bean = ManagerMBean.new("#{@domain}.Manager", "Manager", self)
      @jmx_server.register_mbean(bean, "#{@domain}:type=Manager")
      self.persist_file = config[:persist_file]
    end

    def add(worker_klass, num_workers, worker_options)
      ModernTimes.logger.info "Starting #{worker_klass} with #{num_workers} workers with options #{worker_options.inspect}"
      unless worker_klass.kind_of?(Class)
        begin
          worker_klass = Object.const_get(worker_klass.to_s)
        rescue
          raise ModernTimes::Exception.new("Invalid class: #{worker_klass}")
        end
      end
      if @allowed_workers && !@allowed_workers.include?(worker_klass)
        raise ModernTimes::Exception.new("Error: #{worker_klass.name} is not an allowed worker")
      end
      supervisor = worker_klass.create_supervisor(self, worker_options)
      mbean = supervisor.create_mbean(@domain)
      @supervisors << supervisor
      supervisor.worker_count = num_workers
      @jmx_server.register_mbean(mbean, "#{@domain}:worker=#{supervisor.name},type=Worker")
      ModernTimes.logger.info "Started #{worker_klass.name} with #{num_workers} workers"
    rescue Exception => e
      ModernTimes.logger.error "Exception trying to add #{worker_klass.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    rescue java.lang.Exception => e
      ModernTimes.logger.error "Java exception trying to add #{worker_klass.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    end

    def start
      return if @started
      @started = true

    end

    def stop
      @stopped = true
      @supervisors.each { |supervisor| supervisor.stop }
    end

    def join
      while !@stopped
        sleep 1
      end
      @supervisors.each { |supervisor| supervisor.join }
    end

    def stop_on_signal
      ['HUP', 'INT', 'TERM'].each do |signal_name|
        Signal.trap(signal_name) do
          ModernTimes.logger.info "Caught #{signal_name}"
          stop
        end
      end
    end

    def persist_file=(file)
      @persist_file = file
      return unless file
      @persist_file = file
      if File.exist?(file)
        hash = YAML.load_file(file)
        hash.each do |worker_name, worker_hash|
          klass   = worker_hash[:klass]
          count   = worker_hash[:count]
          options = worker_hash[:options]
          options[:name] = worker_name
          add(klass, count, options)
        end
      end
    end

    def save_persist_state
      return unless @persist_file
      hash = {}
      @supervisors.each do |supervisor|
        hash[supervisor.name] = {
          :klass   => supervisor.worker_klass.name,
          :count   => supervisor.worker_count,
          :options => supervisor.worker_options
        }
      end
      File.open(@persist_file, 'w') do |out|
        YAML.dump(hash, out )
      end
    end
  end
end
