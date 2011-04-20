module ModernTimes
  module JMS
    class SupervisorMBean < ModernTimes::Base::SupervisorMBean
      r_attribute :message_counts, :list, 'Message counts for the workers', :message_counts

      def message_counts
        java.util.ArrayList.new(supervisor.message_counts)
      end
    end
  end
end