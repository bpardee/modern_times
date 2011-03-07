module ModernTimes
  module Railsable
    def init_rails(cfg={})
      if hornetq_cfg = YAML.load_file(File.join(Rails.root, "config", "hornetq.yml"))[Rails.env]
        ModernTimes.logger.info "Messaging Enabled"
        ModernTimes::HornetQ::Client.init(hornetq_cfg)
        @is_hornetq_enabled = true

        # Need to start the HornetQ Server in this VM
        if server_cfg = hornetq_cfg[:server]
          @server = HornetQ::Server.create_server(server_cfg)
          @server.start

          # TODO: Should add check that host given to server is invm
          #if @@server.host == 'invm'
            # Handle messages within this process
            @@manager = Messaging::WorkerManager.new
            @@manager.start
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
      config = YAML.load_file('hornetq.yml')
      ModernTimes::HornetQ::Client.init(config['client'])

      manager = ModernTimes::Manager.new
      manager.stop_on_signal
      manager.allowed_workers = [BarWorker,BazWorker]
      manager.persist_file = 'manager.state'
      #manager.add(BarWorker, 2)
      manager.join

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

require 'hornetq'

# Protocol independent class to handle Messaging and Queuing
module Messaging
  class Client

    # Publish to the specified address
    #   If the supplied object is kind_of? String, then a string is published
    #   Otherwise the Ruby Object is unmarshaled and sent as a Binary message

    # Asynchronously invoke the supplied method
    #
    # Example:
    #   Messaging::Client.async(Dashboard, :update_dashboard_for_inquiry, xml_response)
    def self.async(klass, method, *param)
      @@session_pool.producer(self.async_address) do |session, producer|
        request = AsyncRequest.new
        request.klass = if klass.kind_of?(String)
          klass
        elsif klass.kind_of?(Symbol)
          klass.to_s
        else
          klass.name.to_s
        end
        request.method = method
        request.params = *param
        message = session.create_message(4,false) #HornetQ::Client::Message::BYTES_TYPE
        message['format'] = 'ruby'
        message.body = Marshal.dump(request)
        producer.send(message)
      end
    end

    private
    # Call the specified class passing in the required parameters
    # If the method matches a class method, it is called, otherwise
    # an instance of the class is created and the method is called
    # on the new instance
    #
    # Note: Instance methods are more expensive because the class is instantiated
    #       for every call
    def self.async_on_message(request)
      klass = request.klass.constantize
      method = request.method.to_sym
      if klass.respond_to?(method, false)
        klass.send(method, *request.params)
      else
        klass.new.send(method, *request.params)
      end
    end

    # Passed as the request message, used to hold all required parameters
    class AsyncRequest
      attr_accessor :klass, :method, :params
    end

  end
end

module Messaging
  class WorkerManager
    def initialize
      Dir["#{Rails.root}/app/workers/*_worker.rb"].each {|file| require file}
      file = "#{Rails.root}/config/workers.yml"
      raise "No worker config file #{file}" unless File.exist?(file)
      @config = YAML.load_file(file)[Rails.env] || {}
      @threads = []
    end

    def start
      @config.each do |queue_name, num_workers|
        Rails.logger.info "Creating #{num_workers} threads for #{queue_name}"
        klass = Object.const_get("#{queue_name}Worker")
        (0...num_workers).each do |thread_num|
          worker = klass.new
          worker.thread_number = thread_num
          Messaging::Client.create_queue(worker) if thread_num == 0
          @threads << Thread.new(worker) do |worker|
            Rails.logger.debug "Waiting for a message with #{worker}"
            Messaging::Client.on_message(worker)
            Rails.logger.debug "Finished a message with #{worker}"
            Rails.logger.flush
          end
        end
      end
    end

    def self.sync_call(address, obj)
      Rails.logger.debug "Making synchronous call to #{address}"
      klass = Object.const_get("#{address}Worker")
      worker = klass.new
      worker.perform(obj)
    rescue NameError => e
      Rails.logger.warn "Couldn't make synchronous call for #{address} because there is no matching worker for it"
    end

    def stop
      Messaging::Client.close
      @threads.each { |thread| thread.join }
    end
  end

  def stop_on_signal
    ['HUP', 'INT', 'TERM'].each do |signal_name|
      Signal.trap(signal_name) do
        Rails.logger.info "caught #{signal_name}"
        stop
      end
    end
  end
end
