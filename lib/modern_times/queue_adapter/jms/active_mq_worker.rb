module ModernTimes
  module QueueAdapter
    module JMS
      class ActiveMQWorker < Worker
        def initialize(worker_name, queue_name, topic_name, options)
          if topic_name
            queue_name = "Consumer.#{worker_name}.VirtualTopic.#{topic_name}"
            topic_name = nil
          end
          super(worker_name, queue_name, topic_name, options)
        end
      end
    end
  end
end
