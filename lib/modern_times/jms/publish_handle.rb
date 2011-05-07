require 'timeout'
require 'yaml'

module ModernTimes
  module JMS
    class PublishHandle
      def initialize(publisher, jms_message_id, start)
        @publisher         = publisher
        @jms_message_id    = jms_message_id
        @start             = start
      end

      # Waits the given timeout for a response message on the queue.
      #
      # If called w/o a block:
      #   Returns the message
      #   Returns nil on timeout
      #   Raises RemoteException on a remote exception
      #
      # If called with a block, for instance:
      #   handle.read_response(timeout) do |response|
      #     response.on_message 'CharCount' do |hash|
      #       puts "CharCount returned #{hash.inspect}"
      #     end
      #     response.on_message 'Length', 'Reverse' do |val|
      #       puts "#{response.name} returned #{val}"
      #     end
      #     response.on_message 'ExceptionRaiser' do |val|
      #       puts "#{response.name} didn't raise an exception but returned #{val}"
      #     end
      #     response.on_message do |val|
      #       puts "#{response.name} was caught by the default message handler but if it timed out we wouldn't know since it wasn't explicitly specified"
      #     end
      #     response.on_timeout 'Reverse' do
      #       puts "Reverse has it's own timeout handler"
      #     end
      #     response.on_timeout do
      #       puts "#{response.name} did not respond in time"
      #     end
      #     response.on_remote_exception 'ExceptionRaiser' do
      #       puts "It figures that ExceptionRaiser would raise an exception"
      #     end
      #     response.on_remote_exception do |e|
      #       puts "#{response.name} raised an exception #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      #     end
      #   end
      #
      # The specified blocks will be called for each response.  For instance, LengthWorker#request
      # might return 4 and "Length returned 4" would be displayed.  If it failed to respond within the
      # timeout, then "Length did no respond in time" would be displayed.
      # For Workers that raise an exception, they will either be handled by their specific handler if it exists or
      # the default exception handler.  If that doesn't exist either, then the RemoteException will be raised for the
      # whole read_response call.
      #
      def read_response(timeout, &block)
        reply_queue = @publisher.reply_queue
        raise "Invalid call to read_response for #{@publisher}, not setup for responding" unless reply_queue
        @options = { :destination => reply_queue, :selector => "JMSCorrelationID = '#{@jms_message_id}'" }
        if block_given?
          return read_multiple_response(timeout, &block)
        else
          response = read_single_response(timeout)
          raise response if response.kind_of?(ModernTimes::RemoteException)
          return response
        end
      end

      #######
      private
      #######

      class WorkerResponse
        attr_reader :name

        def initialize
          @message_hash            = {}
          @timeout_hash            = {}
          @exception_hash          = {}
          @default_message_block           = nil
          @default_timeout_block   = nil
          @default_exception_block = nil
          @done_array              = []
        end

        def on_message(*names, &block)
          if names.empty?
            @default_message_block = block
          else
            names.each {|name| @message_hash[name] = block}
          end
        end

        def on_timeout(*names, &block)
          if names.empty?
            @default_timeout_block = block
          else
            names.each {|name| @timeout_hash[name] = block}
          end
        end

        def on_remote_exception(*names, &block)
          if names.empty?
            @default_exception_block = block
          else
            names.each {|name| @exception_hash[name] = block}
          end
          @remote_exception_block = block
        end

        def make_message_call(name, obj)
          # Give the client access to the name
          @name = name
          block = @message_hash[name] || @default_message_block
          block.call(obj) if block
          @done_array << name
        end

        def done?
          (@message_hash.keys - @done_array).empty?
        end

        def make_timeout_calls
          @timeouts = @message_hash.keys - @done_array
          @timeouts.each do |name|
            # Give the client access to the name
            @name = name
            block = @timeout_hash[name] || @default_timeout_block
            block.call if block
          end
        end

        def make_exception_call(name, e)
          @name = name
          block = @exception_hash[name] || @default_exception_block
          if block
            block.call(e)
            @done_array << name
          else
            raise e
          end
        end
      end

      def read_single_response(timeout)
        message = nil
        ModernTimes::JMS::Connection.session_pool.consumer(@options) do |session, consumer|
          leftover_timeout = ((@start + timeout - Time.now) * 1000).to_i
          if leftover_timeout > 100
            message = consumer.receive(leftover_timeout)
          else
            #message = consumer.receive_no_wait
            message = consumer.receive(100)
          end
        end
        return nil unless message
        @name = message['worker']
        if error_yaml = message['exception']
          return ModernTimes::RemoteException.from_hash(YAML.load(error_yaml))
        end
        marshaler = ModernTimes::MarshalStrategy.find(message['marshal'] || :ruby)
        return marshaler.unmarshal(message.data)
      end

      def read_multiple_response(timeout, &block)
        worker_response = WorkerResponse.new
        yield worker_response

        until worker_response.done? do
          response = read_single_response(timeout)
          if !response
            worker_response.make_timeout_calls
            return
          end
          if response.kind_of?(ModernTimes::RemoteException)
            worker_response.make_exception_call(@name, e)
          else
            worker_response.make_message_call(@name, response)
          end
        end
      end
    end
  end
end
