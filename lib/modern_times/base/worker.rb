module ModernTimes
  module Base
    class Worker
      attr_accessor :name, :index, :supervisor, :thread

      def self.supervisor(klass, options={})
        ModernTimes.logger.debug "calling supervisor with klass=#{klass.name} and class=#{self.name}"
#        self.class_eval do
#          define_method :create_supervisor do |manager|
#            puts "calling create_supervisor for klass-#{klass.name} and self=#{self} and manager=#{manager}"
#            klass.new(manager, self, options)
#          end
#        end
        # TODO: This is nasty but I'm not sure how to create a dynamic class method within a scope
        eval <<-EOS
          def self.create_supervisor(manager)
            #{klass.name}.new(manager, self, #{options.inspect})
          end
        EOS
      end

      # Default supervisor is Base::Supervisor
      supervisor Supervisor

      def initialize(opts={})
        @name = opts[:name] || self.class.default_name
      end

      def name
        @name
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

      def self.default_name
        name = self.name.sub(/Worker$/, '')
        name.sub(/::/, '_')
      end
    end
  end
end