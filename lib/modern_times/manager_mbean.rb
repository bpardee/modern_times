require 'jmx'

module ModernTimes
  class ManagerMBean < RubyDynamicMBean
    attr_reader :manager
    r_attribute :allowed_workers, :list, 'Allowed workers'

    def initialize(name, description, manager)
      super(name, description)
      @manager = manager
    end

    def allowed_workers
      all = manager.allowed_workers || ['No Restrictions']
      all = all.map {|worker_klass| worker_klass.name }
      java.util.ArrayList.new(all)
    end

    operation 'Start worker'
    parameter :string, 'worker',  'The worker class to start'
    parameter :int,    'count',   'Number of workers'
    parameter :string, 'options', 'Hash of options (optional)'
    returns :string
    def start_worker(worker, count)
      ModernTimes.logger.debug "Attempting to start #{worker} with count=#{count} and options=#{options}"
      if options.empty?
        opts = {}
      else
        #opts = ModernTimes::MarshalStrategy::JSON
        opts = {}
      end
      manager.add(worker, count, {})
      return 'Successfuly started'
    rescue Exception => e
      ModernTimes.logger.error "Exception starting worker #{worker}: {e.message}\n\t#{e.backtrace.join("\n\t")}"
      return "Exception starting worker #{worker}: {e.message}"
    rescue java.lang.Exception => e
      ModernTimes.logger.error "Java exception starting worker #{worker}: {e.message}\n\t#{e.backtrace.join("\n\t")}"
      return "Java exception starting worker #{worker}: {e.message}"
    end
  end
end