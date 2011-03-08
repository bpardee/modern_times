module ModernTimes
  module Railsable
    def init_rails
      if cfg = YAML.load_file(File.join(Rails.root, "config", "hornetq.yml"))[Rails.env]
        ModernTimes.logger.info "Messaging Enabled"
        ModernTimes::HornetQ::Client.init(cfg)
        @is_hornetq_enabled = true

        # Need to start the HornetQ Server in this VM
        if server_cfg = cfg[:server]
          @server = ::HornetQ::Server.create_server(server_cfg)
          @server.start

          # TODO: Should add check that host given to server is invm
          #if @@server.host == 'invm'
          # Handle messages within this process
          @manager = ModernTimes::Manager.new
          if worker_cfg = cfg[:workers]
            worker_cfg.each do |klass, count|
              @manager.add(klass, count)
            end
          else
            rails_workers.each do |klass|
              @manager.add(klass, 1)
            end
          end
          #end

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
        @is_hornetq_enabled = false
        require 'modern_times/hornetq/dummy_publisher'
        ModernTimes::HornetQ::DummyPublisher.init(rails_workers)
      end
    end

    def init_rails_manager
      cfg = YAML.load_file(File.join(Rails.root, "config", "hornetq.yml"))[Rails.env]
      raise "No valid configuration" unless cfg
      ModernTimes::HornetQ::Client.init(cfg)

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

    def hornetq_enabled?
      @is_hornetq_enabled
    end
  end
end


## Protocol independent class to handle Messaging and Queuing
#module Messaging
#  class Client
#
#    # Publish to the specified address
#    #   If the supplied object is kind_of? String, then a string is published
#    #   Otherwise the Ruby Object is unmarshaled and sent as a Binary message
#
#    # Asynchronously invoke the supplied method
#    #
#    # Example:
#    #   Messaging::Client.async(Dashboard, :update_dashboard_for_inquiry, xml_response)
#    def self.async(klass, method, *param)
#      @@session_pool.producer(self.async_address) do |session, producer|
#        request = AsyncRequest.new
#        request.klass = if klass.kind_of?(String)
#          klass
#        elsif klass.kind_of?(Symbol)
#          klass.to_s
#        else
#          klass.name.to_s
#        end
#        request.method = method
#        request.params = *param
#        message = session.create_message(4,false) #HornetQ::Client::Message::BYTES_TYPE
#        message['format'] = 'ruby'
#        message.body = Marshal.dump(request)
#        producer.send(message)
#      end
#    end
#
#    private
#    # Call the specified class passing in the required parameters
#    # If the method matches a class method, it is called, otherwise
#    # an instance of the class is created and the method is called
#    # on the new instance
#    #
#    # Note: Instance methods are more expensive because the class is instantiated
#    #       for every call
#    def self.async_on_message(request)
#      klass = request.klass.constantize
#      method = request.method.to_sym
#      if klass.respond_to?(method, false)
#        klass.send(method, *request.params)
#      else
#        klass.new.send(method, *request.params)
#      end
#    end
#
#    # Passed as the request message, used to hold all required parameters
#    class AsyncRequest
#      attr_accessor :klass, :method, :params
#    end
#
#  end
#end
