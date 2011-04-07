module ModernTimes
  module JMS
    class Supervisor < ModernTimes::Base::Supervisor
      # Make JMS::SupervisorMBean our mbean
      mbean SupervisorMBean

      attr_reader :message_count

      def initialize(manager, worker_name, supervisor_options, worker_options)
        super
        @message_count = 0
        @message_count_mutex = Mutex.new
      end

      def incr_message_count
        @message_count_mutex.synchronize do
          @message_count += 1
        end
      end
    end
  end
end
