module ModernTimes
  module JMSRequestor
    class Supervisor < ModernTimes::JMS::Supervisor

      def initialize(manager, worker_name, supervisor_options, worker_options)
        super
      end

      def average_response_time
        count = 0
        total = 0.0
        workers.each do |w|
          pair = w.total_time
          count += pair.first
          total += pair.last
        end
        return 0.0 if count == 0
        return total / count
      end

      def min_response_time
        min_time = nil
        workers.each do |w|
          wmin_time = w.min_time
          min_time = wmin_time if wmin_time && (!min_time || wmin_time < min_time)
        end
        return min_time || 0.0
      end

      def max_response_time
        max_time = 0.0
        workers.each do |w|
          wmax_time = w.max_time
          max_time = wmax_time if wmax_time > max_time
        end
        return max_time
      end

      # Make JMSRequestor::SupervisorMBean our mbean
      def create_mbean(domain)
        SupervisorMBean.new(mbean_name(domain), mbean_description, self, {})
      end
    end
  end
end
