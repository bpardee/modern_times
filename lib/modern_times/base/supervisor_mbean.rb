require 'jmx'

module ModernTimes
  module Base
    class SupervisorMBean < RubyDynamicMBean
      attr_reader  :supervisor
      rw_attribute :worker_count, :int, "Number of workers"
      r_attribute  :worker_statuses, :list, 'Status of the workers'

      def initialize(name, description, supervisor, options)
        super(name, description)
        @supervisor = supervisor
      end

      def worker_count
        supervisor.worker_count
      end

      def worker_count=(count)
        supervisor.worker_count = count
      end

      def worker_statuses
        java.util.ArrayList.new(supervisor.worker_statuses)
      end
    end
  end
end