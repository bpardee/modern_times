module ModernTimes
  module Railsable
    def init_rails
      if cfg = YAML.load_file(File.join(Rails.root, "config", "jms.yml"))[Rails.env]
        ModernTimes.logger.info "Messaging Enabled"
        ModernTimes::JMS::Connection.init(cfg)
        @is_jms_enabled = true

        # Need to start the JMS Server in this VM
        if ModernTimes::JMS::Connection.invm?
          @server = ::JMS::Server.create_server('jms://invm')
          @server.start

          # Handle messages within this process
          @manager = ModernTimes::Manager.new
          # TODO: Formatting of configured workers in invm state with name and options
          if worker_cfg = cfg[:workers]
            worker_cfg.each do |klass, count|
              @manager.add(klass, count, {})
            end
          else
            rails_workers.each do |klass|
              @manager.add(klass, 1, {})
            end
          end

          at_exit do
            @manager.stop if @manager
            @server.stop
          end
        end

        # Create Async Queue and handle requests
        #self.async_queue_name = self.async_address = "Messaging::Client.async"
        #self.on_message(self.async_address, self.async_queue_name) do |request|
        #  self.async_on_message(request)
        #end

      else
        Rails.logger.info "Messaging disabled"
        @is_jms_enabled = false
        ModernTimes::JMS::Publisher.setup_dummy_publishing(rails_workers)
      end
    end

    def create_rails_manager
      cfg = YAML.load_file(File.join(Rails.root, "config", "jms.yml"))[Rails.env]
      raise "No valid configuration" unless cfg
      ModernTimes::JMS::Connection.init(cfg)

      manager = ModernTimes::Manager.new
      manager.stop_on_signal
      manager.allowed_workers = rails_workers
      manager.persist_file = cfg[:persist_file] || File.join(Rails.root, "log", "modern_times.persist")
      return manager
    end

    def rails_workers
      @rails_workers ||= begin
        workers = []
        Dir["#{Rails.root}/app/workers/*_worker.rb"].each do |file|
          require file
          workers << File.basename(file).sub(/\.rb$/, '').classify.constantize
        end
        workers
      end
      #file = "#{Rails.root}/config/workers.yml"
      #raise "No worker config file #{file}" unless File.exist?(file)
    end

    def jms_enabled?
      @is_jms_enabled
    end
  end
end
