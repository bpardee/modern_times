module ModernTimes
  module HornetQ
    class Supervisor < ModernTimes::Base::Supervisor
      # Make HornetQ::SupervisorMBean our mbean
      mbean SupervisorMBean

      attr_reader :message_count

      def initialize(manager, worker_name, opts={})
        super(manager, worker_name, opts)
        @message_count = 0
      end

      def incr_message_count
        @message_count += 1
      end
    end
  end
end
