module ModernTimes
  module HornetQ

    # For non-configured Rails projects, Client.publish will be overridden to
    # call this publish method instead which calls all the HornetQ workers that
    # operate on the given address.
    module DummyPublisher
      def self.init(workers)
        Client.extend self
        Client.workers = workers
      end

      def publish(address, object)
        @worker_instances.each do |worker|
          if worker.kind_of?(Worker) && worker.address_name == address
            ModernTimes.logger.debug "Publishing #{object} to #{worker}"
            worker.perform(object)
          end
        end
      end

      def workers=(workers)
        @worker_instances = workers.map {|worker| worker.new}
      end
    end
  end
end