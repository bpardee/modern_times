require 'yaml'
require 'socket'

module ModernTimes
  class Manager
    attr_accessor :allowed_workers, :dummy_host
    attr_reader   :supervisors

    def initialize(config={})
      @stopped = false
      @config = config
      @domain = config[:domain] || ModernTimes::DEFAULT_DOMAIN
      @supervisors = []
      self.persist_file = config[:persist_file]
      self.worker_file  = config[:worker_file]
      @allowed_workers = config[:allowed_workers]
      stop_on_signal if config[:stop_on_signal]
      @dummy_host = config[:dummy_host]
      # Unless specifically unconfigured (i.e., Rails.env == test), then enable jmx
      if config[:jmx] != false
        @jmx_server = JMX::MBeanServer.new
        bean = ManagerMBean.new(@domain, self)
        @jmx_server.register_mbean(bean, ModernTimes.manager_mbean_object_name(@domain))
      end
    end

    def add(worker_klass, num_workers, worker_options={})
      ModernTimes.logger.info "Starting #{worker_klass} with #{num_workers} workers with options #{worker_options.inspect}"
      unless worker_klass.kind_of?(Class)
        begin
          worker_klass = Object.const_get(worker_klass.to_s)
        rescue
          raise "Invalid class: #{worker_klass}"
        end
      end
      if @allowed_workers && !@allowed_workers.include?(worker_klass)
        raise "Error: #{worker_klass.name} is not an allowed worker"
      end
      supervisor = worker_klass.create_supervisor(self, worker_options)
      raise "A supervisor with name #{supervisor.name} already exists" if find_supervisor(supervisor.name)
      @supervisors << supervisor
      supervisor.worker_count = num_workers
      if @jmx_server
        mbean = supervisor.create_mbean(@domain)
        @jmx_server.register_mbean(mbean, "#{@domain}:worker=#{supervisor.name},type=Worker")
      end
      ModernTimes.logger.info "Started #{worker_klass.name} named #{supervisor.name} with #{num_workers} workers"
    rescue Exception => e
      ModernTimes.logger.error "Exception trying to add #{worker_klass}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      raise
    rescue java.lang.Exception => e
      ModernTimes.logger.error "Java exception trying to add #{worker_klass.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      raise
    end

    # TODO: Get rid of this or prevent worker thread creation until it's been called?
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

    def find_supervisor(name)
      @supervisors.each do |supervisor|
        return supervisor if supervisor.name == name
      end
      return nil
    end

    def worker_file=(file)
      return unless file
      @worker_file = file
      if File.exist?(file)
        hash = YAML.load_file(file)
        config = @dummy_host && hash[@dummy_host]
        unless config
          host = Socket.gethostname.sub(/\..*/, '')
          config = hash[host]
        end
        return unless config
        # Don't save new states if the user never dynamically updates the workers
        # Then they can solely define the workers via this file and updates to the counts won't be ignored.
        save_persist_file = @persist_file
        @persist_file = nil unless File.exist?(@persist_file)
        begin
          config.each do |worker_name, worker_hash|
            # Don't add if persist_file already created this supervisor
            next if find_supervisor(worker_name)
            klass   = worker_hash[:klass] || "#{worker_name}Worker"
            count   = worker_hash[:count]
            options = worker_hash[:options] || {}
            options[:name] = worker_name
            add(klass, count, options)
          end
        ensure
          @persist_file = save_persist_file
        end
      end
    end
  end
end
