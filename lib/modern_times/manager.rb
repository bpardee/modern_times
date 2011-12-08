require 'erb'
require 'yaml'
require 'socket'
require 'rumx'

module ModernTimes
  class Manager
    include Rumx::Bean
    attr_reader   :env, :worker_configs, :name

    # Constructs a manager.  Accepts a hash of config options
    #   name         - name which this bean will be added
    #   parent_bean  - parent Rumx::Bean that this bean will be a child of.  Defaults to the Rumx::Bean.root
    #   env          - environment being executed under.  For a rails project, this will be the value of Rails.env
    #   worker_file  - the worker file is a hash with the environment or hostname as the primary key and a subhash with the worker names
    #     as the keys and the config options for the value.  In this file, the env will be searched first and if that doesn't exist,
    #     the hostname will then be searched.  Workers can be defined for development without having to specify the hostname.  For
    #     production, a set of workers could be defined under production or specific workers for each host name.
    #   persist_file - WorkerConfig attributes that are modified externally (via Rumx interface) will be stored in this file.  Without this
    #     option, external config changes that are made will be lost when the Manager is restarted.
    def initialize(options={})
      @stopped          = false
      @name             = options[:name] || ModernTimes::DEFAULT_NAME
      parent_bean       = options[:parent_bean] || Rumx::Bean.root
      @worker_configs   = []
      @env              = options[:env]
      @worker_options   = parse_worker_file(options[:worker_file])
      @persist_file     = options[:persist_file]
      @persist_options  = (@persist_file && File.exist?(@persist_file)) ? YAML.load_file(@persist_file) : {}

      BaseWorker.worker_classes.each do |worker_class|
        worker_config_class = worker_class.config_class
        worker_class.each_config do |config_name, options|
          # Least priority is config options defined in the Worker class, then the workers.yml file, highest priority is persist_file (ad-hoc changes made manually)
          options = options.merge(@worker_options[config_name]) if @worker_options[config_name]
          options = options.merge(@persist_options[config_name]) if @persist_options[config_name]
          worker_config = worker_config_class.new(config_name, self, worker_class, options)
          bean_add_child(config_name, worker_config)
          @worker_configs << worker_config
        end
      end

      parent_bean.bean_add_child(@name, self)
      stop_on_signal if options[:stop_on_signal]
    end

    def stop
      return if @stopped
      @stopped = true
      @worker_configs.each { |worker_config| worker_config.stop }
    end

    def stop_on_signal
      ['HUP', 'INT', 'TERM'].each do |signal_name|
        Signal.trap(signal_name) do
          ModernTimes.logger.info "Caught #{signal_name}"
          stop
        end
      end
    end

    def save_persist_state
      return unless @persist_file
      new_persist_options = {}
      BaseWorker.worker_classes.each do |worker_class|
        worker_class.each_config do |config_name, options|
          static_options = options.merge(@worker_options[config_name] || {})
          worker_config = self[config_name]
          hash = {}
          # Only store off the config values that are specifically different from default values or values set in the workers.yml file
          # Then updates to these values will be allowed w/o being hardcoded to an old default value.
          worker_config.bean_get_attributes do |attribute, value, rel_path, param_name|
            hash[param_name.to_sym] = value if attribute[:config_item] && static_options[param_name.to_sym] != value
          end
          new_persist_options[config_name] = hash unless hash.empty?
        end
      end
      if new_persist_options != @persist_options
        @persist_options = new_persist_options
        File.open(@persist_file, 'w') do |out|
          YAML.dump(@persist_options, out )
        end
      end
    end

    def [](name)
      @worker_configs.each do |worker_config|
        return worker_config if worker_config.name == name
      end
      return nil
    end

    #######
    private
    #######

    def parse_worker_file(file)
      if file && File.exist?(file)
        hash = YAML.load(ERB.new(File.read(file)).result(binding))
        options = @env && hash[@env]
        unless options
          host = Socket.gethostname.sub(/\..*/, '')
          options = hash[host]
        end
      end
      return options || {}
    end
  end
end
