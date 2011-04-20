module ModernTimes
  module JMS
    class Supervisor < ModernTimes::Base::Supervisor

      def initialize(manager, worker_name, supervisor_options, worker_options)
        super
      end

      def message_counts
        workers.map { |w| w.message_count }
      end

      # Make JMS::SupervisorMBean our mbean
      def create_mbean(domain)
        SupervisorMBean.new(mbean_name(domain), mbean_description, self, {})
      end
    end
  end
end
