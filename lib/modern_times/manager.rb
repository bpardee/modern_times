module ModernTimes
  class Manager
    attr_accessor :allowed_workers

    def initialize(config={})
      @config = config
      @domain = config[:domain] || 'ModernTimes'
      @supervisors = []
      @jmx_server = JMX::MBeanServer.new
      bean = ManagerMBean.new("#{@domain}.Manager", "Manager", self)
      @jmx_server.register_mbean(bean, "#{@domain}:type=Manager")
    end

    def add(worker_klass, num_workers)
      ModernTimes.logger.info "Starting #{worker_klass} with #{num_workers} workers"
      if worker_klass.kind_of?(String)
        begin
          worker_klass = Object.const_get(worker_klass)
        rescue
          raise ModernTimes::Exception.new("Invalid class: #{worker_klass}")
        end
      end
      if @allowed_workers && !@allowed_workers.include?(worker_klass)
        raise ModernTimes::Exception.new("Error: #{worker_klass.name} is not an allowed worker")
      end
      supervisor = worker_klass.create_supervisor(self)
      mbean = supervisor.create_mbean(@domain)
      @supervisors << supervisor
      supervisor.worker_count = num_workers
      @jmx_server.register_mbean(mbean, "#{@domain}:worker=#{worker_klass.name},type=Worker")
      ModernTimes.logger.info "Started #{worker_klass.name} with #{num_workers} workers"
    rescue Exception => e
      ModernTimes.logger.error "Exception trying to add #{worker_klass.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    rescue java.lang.Exception => e
      ModernTimes.logger.error "Java exception trying to add #{worker_klass.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
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
      if File.exist?(file)
        hash = YAML.load_file(file)
        hash.each do |worker_klass, count|
          add(worker_klass, count)
        end
      end
    end

    def save_persist_state
      return unless @persist_file
      hash = {}
      @supervisors.each { |supervisor| hash[supervisor.worker_klass.name] = supervisor.worker_count }
      File.open(@persist_file, 'w') do |out|
        YAML.dump(hash, out )
      end
    end
  end
end
