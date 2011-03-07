module ModernTimes
  module HornetQ
    class SupervisorMBean < ModernTimes::Base::SupervisorMBean

      operation 'Total message count'
      returns :int
      def message_count
        supervisor.message_count
      end
    end
  end
end