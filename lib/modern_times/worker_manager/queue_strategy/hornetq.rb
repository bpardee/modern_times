require 'modern_times/stoppable'
require 'hornetq'
require 'ostruct'

module ModernTimes
  module WorkerManager
    module QueueStrategy
      class HornetQ
        include ModernTimes::Stoppable

        # an array of queue config objects which is just a hash as follows:
        #  queue:
        #    name: MyQueue
        #    class: MyQueueWorker
        #    workers: 50              (optional, defaults to 1)
        #    fail_queue: MyQueueFail (optional, defaults to nil)
        def initialize(queue, connector_opts, session_opts)
          @queue = queue
          @factory = HornetQ::Client::Factory.create_factory(connector_opts)
          @session_opts = session_opts
        end

        def create_session
          session = @factory.create_session(@session_opts)
          consumer = session.create_consumer(@queue)
          session.start
          return OpenStruct.new(:session => session, :consumer => consumer)
        end

        def interrupt_session(info)
          info.session.close
        end

        def destroy_session(info)
          #info.session.close
        end

        def receive(info)
          info.consumer.receive
        end

        def failed(session, value)
          ModernTimes.logger.warn "Failed for #{session} with value #{value}"
        end

        def stop
          super
          # Clobber connection
          @factory.close
        end
      end
    end
  end
end
