module ModernTimes
  module JMSRequestor
    class Requestor < ModernTimes::JMS::Publisher
      attr_reader :reply_queue

      def initialize(options)
        super
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
      def dummy_request(object)
        @@worker_instances.each do |worker|
          if worker.kind_of?(Worker) && worker.address_name == address
            ModernTimes.logger.debug "Dummy requesting #{object} to #{worker}"
            return new OpenStruct(:read_response => worker.request(object))
          end
        end
        raise "No worker to handle #{address} request of #{object}"
      end

      def self.setup_dummy_requesting(workers)
        @@worker_instances = workers.map {|worker| worker.new}
        alias_method :real_request, :request
        alias_method :request, :dummy_request
      end
    end
  end
end
