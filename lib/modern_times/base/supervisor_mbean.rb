require 'jmx'

module ModernTimes
  module Base
    class SupervisorMBean < RubyDynamicMBean
      attr_reader :supervisor
      rw_attribute :worker_count, :int, "Number of workers"

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

      operation 'Get the worker status'
      parameter :int, "index", "Index of the worker"
      returns :string
      def worker_status(index)
        supervisor.worker_status(index)
      end
    end
  end
end