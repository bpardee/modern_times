module ModernTimes
  module JMSRequestor

    # Base Worker Class for any class that will be processing messages from queues
    module Worker
      include ModernTimes::JMS::Worker
      attr_reader :error_count

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
        @time_mutex  = Mutex.new
        @count       = 0
        @error_count = 0
        @min_time    = nil
        @max_time    = 0.0
        @total_time  = 0.0
      end

      def perform(object)
        start_time = Time.now
        response = request(object)
        response_time = Time.now - start_time
        session.producer(:destination => message.reply_to) do |producer|
          reply_message = ModernTimes::JMS.create_message(session, self.class.marshaler, response)
          reply_message.jms_correlation_id = message.jms_message_id
          producer.send(reply_message)
        end
        @time_mutex.synchronize do
          @count      += 1
          @total_time += response_time
          @min_time    = response_time if !@min_time || response_time < @min_time
          @max_time    = response_time if response_time > @max_time
        end
      rescue Exception => e
        @time_mutex.synchronize do
          @error_count += 1
        end
        begin
          session.producer(:destination => message.reply_to) do |producer|
            reply_message = ModernTimes::JMS.create_message(session, ModernTimes::MarshalStrategy::String, "Exception: #{e.message}")
            reply_message.jms_correlation_id = message.jms_message_id
            reply_message['Exception'] = ModernTimes::RemoteException.new(e).to_hash.to_yaml
            producer.send(reply_message)
          end
        rescue Exception => e
          ModernTimes.logger.error("Exception in exception reply: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
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
