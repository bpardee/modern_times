# Protocol independent class to handle Publishing
module ModernTimes
  class Publisher
    #attr_reader :producer_options, :persistent, :marshaler, :reply_queue
    attr_reader :response_options, :adapter

    # Parameters:
    #   One of the following must be specified
    #     :queue_name            => String: Name of the Queue to publish to
    #     :topic_name            => String: Name of the Topic to publish to
    #   Optional:
    #     :time_to_live          => expiration time in ms for the message (JMS)
    #     :persistent            => true or false (defaults to false) (JMS)
    #     :marshal               => Symbol: One of :ruby, :string, :json, :bson, :yaml or any registered types (See ModernTimes::MarshalStrategy), defaults to :ruby
    #     :response              => if true or a hash of response options, a temporary reply queue will be setup for handling responses
    #       :time_to_live        => expiration time in ms for the response message(s) (JMS))
    #       :persistent          => true or false for the response message(s), set to false if you don't want timed out messages ending up in the DLQ (defaults to true unless time_to_live is set)
    def initialize(options)
      options = options.dup
      @queue_name = options.delete(:queue_name)
      @topic_name = options.delete(:topic_name)
      raise "One of :queue_name or :topic_name must be given in #{self.class.name}" if !@queue_name && !@topic_name

      @response_options = options.delete(:response)
      # response_options should only be a hash or the values true or false
      @response_options = {} if @response_options && !@response_options.kind_of?(Hash)

      @adapter          = QueueAdapter.create_publisher(@queue_name, @topic_name, options, @response_options)
      @marshal_sym      = options[:marshal] || :ruby
      @marshaler        = ModernTimes::MarshalStrategy.find(@marshal_sym)
    end

    # Publish the given object to the address.
    def publish(object, props={})
      start = Time.now
      marshaled_object = @marshaler.marshal(object)
      message_id = @adapter.publish(marshaled_object, @marshal_sym, @marshaler.marshal_type, props)
      return PublishHandle.new(self, message_id, start)
    end

    def to_s
      "#{self.class.name}:#{@queue_name || @topic_name}"
    end
  end
end
