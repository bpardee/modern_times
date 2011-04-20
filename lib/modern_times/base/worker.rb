module ModernTimes
  module Base
    module Worker
      attr_accessor :name, :index, :thread

      module ClassMethods
        def default_name
          name = self.name.sub(/Worker$/, '')
          name.sub(/::/, '_')
        end

        def create_supervisor(manager, worker_options)
          Supervisor.new(manager, self, {}, worker_options)
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      def initialize(opts={})
        @name = opts[:name] || self.class.default_name
      end

      # One time initialization prior to first thread
      def setup
      end

      def start(name)
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