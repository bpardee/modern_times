module ModernTimes
  module Base
    class Worker
      attr_accessor :index, :supervisor, :thread

      def self.supervisor(klass, options={})
        self.class.class_eval do
          define_method :create_supervisor do |manager|
            klass.new(manager, self, options)
          end
        end
      end

      # Default supervisor is Base::Supervisor
      supervisor Supervisor

      def initialize(opts={})
      end

      # One time initialization prior to first thread
      def setup
      end

      def start
        raise "Need to override start method in #{self.class.name}"
      end

      def stop
        raise "Need to override stop method in #{self.class.name}"
      end

      def status
        raise "Need to override status method in #{self.class.name}"
      end
    end
  end
end