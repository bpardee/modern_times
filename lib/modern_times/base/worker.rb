require 'json'

module ModernTimes
  module Base
    module Worker
      attr_accessor :index, :supervisor, :thread

      module ClassMethods
        def create_supervisor(manager, worker_options)
          Supervisor.new(manager, self, {}, worker_options)
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

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