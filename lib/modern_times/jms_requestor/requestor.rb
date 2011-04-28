module ModernTimes
  module JMSRequestor
    class Requestor < ModernTimes::JMS::Publisher
      attr_reader :reply_queue

      @@dummy_requesting = false

      def initialize(options)
        super
        return if @@dummy_requesting
        raise "ModernTimes::JMS::Connection has not been initialized" unless ModernTimes::JMS::Connection.inited?
        ModernTimes::JMS::Connection.session_pool.session do |session|
          @reply_queue = session.create_destination(:queue_name => :temporary)
        end
      end
      
      def request(object, timeout)
        start = Time.now
        message = publish(object, :jms_reply_to => @reply_queue)
        return RequestHandle.new(self, message, start, timeout)
      end

      # For non-configured Rails projects, The above request method will be overridden to
      # call this request method instead which calls all the JMS workers that
      # operate on the given address.
      def dummy_request(object, timeout)
        @@worker_instances.each do |worker|
          if worker.kind_of?(Worker) && ModernTimes::JMS.same_destination?(producer_options, worker.destination_options)
            ModernTimes.logger.debug "Dummy requesting #{object} to #{worker}"
            return new OpenStruct(:read_response => worker.request(object))
          end
        end
        raise "No worker to handle #{address} request of #{object}"
      end

      def self.setup_dummy_requesting(workers)
        @@dummy_requesting = true
        @@worker_instances = workers.map {|worker| worker.new}
        alias_method :real_request, :request
        alias_method :request, :dummy_request
      end

      # For testing
      def self.clear_dummy_requesting
        @@dummy_requesting = false
        alias_method :dummy_request, :request
        alias_method :request, :real_request
      end
    end
  end
end
