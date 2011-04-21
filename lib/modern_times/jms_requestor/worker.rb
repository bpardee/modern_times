module ModernTimes
  module JMSRequestor

    # Base Worker Class for any class that will be processing messages from queues
    module Worker
      include ModernTimes::JMS::Worker

      module ClassMethods
        def create_supervisor(manager, worker_options)
          Supervisor.new(manager, self, {}, worker_options)
        end
      end

      def self.included(base)
        # The price we pay for including rather than extending
        base.extend(ModernTimes::Base::Worker::ClassMethods)
        base.extend(ModernTimes::JMS::Worker::ClassMethods)
        base.extend(ClassMethods)
      end

      def initialize(opts={})
        super
        @time_mutex = Mutex.new
        @count      = 0
        @min_time   = nil
        @max_time   = 0.0
        @total_time = 0.0
      end

      def perform(object)
        start_time = Time.now
        response = request(object)
        response_time = Time.now - start_time
        session.producer(:destination => message.reply_to) do |producer|
          reply_message = session.message(self.class.marshaler.marshal(response))
          reply_message.jms_correlation_id = message.jms_message_id
          #producer.send_with_retry(reply_message)
          producer.send(reply_message)
        end
        @time_mutex.synchronize do
          @count      += 1
          @total_time += response_time
          @min_time    = response_time if !@min_time || response_time < @min_time
          @max_time    = response_time if response_time > @max_time
        end
      end

      def total_time
        @time_mutex.synchronize do
          retval = [@count, @total_time]
          @count = 0
          @total_time = 0.0
          return retval
        end
      end

      def min_time
        @time_mutex.synchronize do
          val = @min_time
          @min_time = nil
          return val
        end
      end

      def max_time
        @time_mutex.synchronize do
          val = @max_time
          @max_time = 0.0
          return val
        end
      end

      def request(object)
        raise "#{self}: Need to override request method in #{self.class.name} in order to act on #{object}"
      end
    end
  end
end
