module ModernTimes
  module JMS
    class SupervisorMBean < ModernTimes::Base::SupervisorMBean
      r_attribute :message_count, :int, 'Total message count', :message_count

      def message_count
        supervisor.message_count
      end

    end
  end
end