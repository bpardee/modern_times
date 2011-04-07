module ModernTimes
  module Base
    class Supervisor
      attr_reader :manager, :worker_klass, :name, :worker_options

      # Create new supervisor to manage a number of similar workers
      # supervisor_options are those options defined on the Worker's Supervisor line
      # worker_options are options passed in when creating a new instance
      def initialize(manager, worker_klass, supervisor_options, worker_options)
        @stopped        = false
        @manager        = manager
        @worker_klass   = worker_klass
        @name           = worker_options.delete(:name) || worker_klass.default_name
        @worker_options = worker_options
        @workers        = []
        @worker_mutex   = Mutex.new
        @failure_mutex  = Mutex.new
      end

      def worker_count
        @workers.size
      end

      def worker_count=(count)
        @worker_mutex.synchronize do
          ModernTimes.logger.info "#{@worker_klass.name}: Changing number of workers from #{@workers.size} to #{count}"
          raise "#{@worker_klass.name}: Can't change worker_count, this manager has been stopped" if stopped?
          curr_count = @workers.size
          if curr_count < count
            (curr_count...count).each do |index|
              worker = @worker_klass.new(@worker_options)
              worker.supervisor = self
              worker.index = index
              if index == 0
                # JMS hack:  If I create the session in the jmx thread, it dies with no feedback
                tmp_thread = Thread.new do
                  worker.setup
                end
                tmp_thread.join
              end
              worker.thread = Thread.new do
                #ModernTimes.logger.debug "#{worker}: Started thread with priority #{Thread.current.priority}"
                worker.start
              end
              @workers << worker
            end
          elsif curr_count > count
            (count...curr_count).each { |index| @workers[index].stop }
            (count...curr_count).each { |index| @workers[index].thread.join }
            @workers = @workers[0, count]
          end
          manager.save_persist_state
        end
      end

      def worker_status(index)
        @workers[index].status
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
        @workers.each { |worker| worker.thread.join }
      end

      def failure(worker, message)
        
      end

      def self.mbean(klass, options={})
#        self.class.class_eval do
#          define_method :create_mbean do |domain, supervisor, worker_klass|
#            klass.new("#{domain}.Worker.#{worker_klass.name}", "Supervisor for #{worker_klass.name}", supervisor, options)
#          end
#        end
        # TODO: This is nasty but I'm not sure how to create a dynamic class method within a scope
        eval <<-EOS
          def self.create_mbean(domain, supervisor, worker_klass)
            #{klass.name}.new("\#{domain}.Worker.\#{worker_klass.name}", "Supervisor for \#{worker_klass.name}", supervisor, #{options.inspect})
          end
        EOS
      end

      def create_mbean(domain)
        self.class.create_mbean(domain, self, @worker_klass)
      end

      #########
      protected
      #########
    end
  end
end