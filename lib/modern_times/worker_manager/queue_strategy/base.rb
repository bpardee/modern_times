require 'modern_times/stoppable'
require 'hornetq'

module ModernTimes
  module WorkerManager
    module QueueStrategy
      class Base
        include ModernTimes::Stoppable

        def create_session
        end

        def receive(session)
        end

        def failed(session, value)
          ModernTimes.logger.info "Failed for #{session} with value #{value}"
        end
      end
    end
  end
end
