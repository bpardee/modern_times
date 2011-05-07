module ModernTimes
  module JMS
    class SupervisorMBean < ModernTimes::Base::SupervisorMBean
      r_attribute :message_counts,        :list,  'Message counts for the workers', :message_counts
      r_attribute :average_response_time, :float, 'Average response time',          :average_response_time
      r_attribute :min_response_time,     :float, 'Minimum response time',          :min_response_time
      r_attribute :max_response_time,     :float, 'Maximum response time',          :max_response_time

      def message_counts
        java.util.ArrayList.new(supervisor.message_counts)
      end

      def average_response_time
        supervisor.average_response_time
      end

      def min_response_time
        supervisor.min_response_time
      end

      def max_response_time
        supervisor.max_response_time
      end

    end
  end
end