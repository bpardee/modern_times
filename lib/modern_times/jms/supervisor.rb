module ModernTimes
  module JMS
    class Supervisor < ModernTimes::Base::Supervisor

      def initialize(manager, worker_name, supervisor_options, worker_options)
        super
      end

      def message_counts
        workers.map { |w| w.message_count }
      end

      def average_response_time
        count = 0
        total = 0.0
        workers.each do |w|
          pair = w.time_track.total_time_reset
          count += pair.first
          total += pair.last
        end
        return 0.0 if count == 0
        return total / count
      end

      def min_response_time
        min_time = nil
        workers.each do |w|
          wmin_time = w.time_track.min_time_reset
          min_time = wmin_time if wmin_time && (!min_time || wmin_time < min_time)
        end
        return min_time || 0.0
      end

      def max_response_time
        max_time = 0.0
        workers.each do |w|
          wmax_time = w.time_track.max_time_reset
          max_time = wmax_time if wmax_time > max_time
        end
        return max_time
      end

      # Make JMS::SupervisorMBean our mbean
      def create_mbean(domain)
        SupervisorMBean.new(mbean_name(domain), mbean_description, self, {})
      end
    end
  end
end
