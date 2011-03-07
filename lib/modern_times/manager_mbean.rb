require 'jmx'

module ModernTimes
  class ManagerMBean < RubyDynamicMBean
    attr_reader :manager
    rw_attribute :foobar, :int, "Number of workers"

    def initialize(name, description, manager)
      super(name, description)
      @manager = manager
    end

    operation 'Allowed workers'
    returns :list
    def allowed_workers
      all = manager.allowed_workers || ['No Restrictions']
      all.map {|worker_klass| worker_klass.name }
    end

    operation 'Start worker'
    parameter :string, "worker", "The worker class to start"
    parameter :int, "count", "Number of workers"
    returns :string
    def start_worker(worker, count)
      ModernTimes.logger.debug "Attempting to start #{worker} with count=#{count}"
      manager.add(worker, count)
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