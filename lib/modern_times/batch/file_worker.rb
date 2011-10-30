module ModernTimes
  module Batch

    # Batch worker which reads records from files and queues them up for a separate worker (ModernTimes::JMS::RequestWorker) to process.
    # For instance, a worker of this type might look as follows:
    #   class MyBatchWorker
    #     include ModernTimes::Batch::FileWorker
    #
    #     file :glob => '/home/batch_files/input/**', :age => 1.minute, :max_outstanding_records => 100, :fail_threshold => 0.8, :save_period => 30.seconds
    #     marshal :string
    #   end
    #
    # The following options can be used for configuring the class
    #   file:
    #     :glob => <glob_path>
    #       The path where files will be processed from.  Files will be renamed with a .processing extension while they are being processed
    #       and to a .completed extension when processing is completed.
    #     :age => <duration>
    #       How old a file must be before it will be processed.  This is to prevent files that are in the middle of being uploaded from begin acquired.
    #     :poll_time => <duration>
    #       How often the glob is queried for new files.
    #     :max_outstanding_records => <integer>
    #       This is how many outstanding records can be queued at a time.
    #     :
    module FileWorker
      include ModernTimes::Base::Worker

      module ClassMethods
        # Define the marshaling and time_to_live that will occur on the response
        def file(options)
          @file_options = options
        end

        def file_options
          @file_options
        end

        def marshal(marshal_type)
          @marshal_type = marshal_type
        end

        def marshal_type
          @marshal_type
        end

        def queue(name, opts={})
          @queue_name = name
          @reply_queue_name = opts[:reply_queue]
        end

        def queue_name
          @queue_name
        end

        def reply_queue_name
          @reply_queue_name
        end
      end

      def self.included(base)
        base.extend(ModernTimes::Base::Worker::ClassMethods)
        base.extend(ClassMethods)
      end

      # Set the global default acquire_file_strategy for an organization
      def self.default_acquire_file_strategy=(default_strategy)
        @@default_acquire_file_strategy = default_strategy
      end

      def self.default_acquire_file_strategy
        @@default_acquire_file_strategy
      end

      # Set the global default parse_file_strategy for an organization
      def self.default_parse_file_strategy=(default_strategy)
        @@default_parse_file_strategy = default_strategy
      end

      def self.default_parse_file_strategy
        @@default_parse_file_strategy
      end

      # Set the global default process_file_strategy for an organization
      def self.default_file_status_strategy=(default_strategy)
        @@default_file_status_strategy = self.file_status_strategy_from_sym(default_strategy)
      end

      def self.default_file_status_strategy
        self.file_status_strategy_to_sym(@@default_file_status_strategy)
      end

      def self.file_status_strategy_from_sym(strategy)
        if strategy.kind_of?(Symbol)
          if strategy == :active_record
            require 'modern_times/batch/active_record'
            ModernTimes::Batch::ActiveRecord::BatchJob
          elsif strategy == :mongoid
            require 'modern_times/batch/mongoid'
            ModernTimes::Batch::Mongoid::BatchJob
          else
            raise "Invalid symbol for file_status_strategy=#{strategy}"
          end
        else
          strategy
        end
      end

      def self.file_status_strategy_to_sym(strategy)
        if strategy == ModernTimes::Batch::ActiveRecord::BatchJob
          :active_record
        elsif strategy == ModernTimes::Batch::ActiveRecord::BatchJob
          :mongoid
        else
          strategy
        end
      end

      self.default_acquire_file_strategy = AcquireFileStrategy
      self.default_parse_file_strategy = ParseFileStrategy
      self.default_file_status_strategy = begin
        if defined?(ActiveRecord)
          :active_record
        elsif defined?(Mongoid)
          :mongoid
        else
          nil
        end
      end

      def initialize(opts={})
        super
        @marshal_type     = (self.class.marshal_type || :ruby).to_s
        @marshaler        = MarshalStrategy.find(@marshal_type)
        @stopped          = false
        @queue_name       = opts[:queue_name] || self.class.queue_name || (self.name.match(/(.*)File$/) && $1)
        raise "queue_name not specified in #{self.class.name}" unless @queue_name
        @reply_queue_name = opts[:reply_queue_name] || self.class.reply_queue_name || "#{@queue_name}Reply"

        file_options = self.class.file_options
        raise "file_options not set for #{self.class.name}" unless file_options
        acquire_strategy_class = file_options.delete(:acquire_strategy) || FileWorker.default_acquire_file_strategy
        parse_strategy_class   = file_options.delete(:parse_strategy)   || FileWorker.default_parse_file_strategy
        status_strategy        = file_options.delete(:status_strategy)  || FileWorker.default_parse_file_strategy
        raise 'No status_strategy defined' unless status_strategy
        status_strategy_class  = FileWorker.file_status_strategy_from_sym(status_strategy)
        @acquire_file_strategy = acquire_strategy_class.new(file_options)
        @parse_file_strategy   = parse_strategy_class.new(file_options)
        @file_status_strategy  = status_strategy_class.new(file_options)
        @max_outstanding_records = file_options[:max_outstanding_records] || 10
      end

      def start
        #TODO: look for current job
        while file = @acquire_file_strategy.acquire_file do
          @parse_file_strategy.open(file)
          @reply_thread = Thread.new do
            java.lang.Thread.current_thread.name = "ModernTimes worker (reply): #{worker}"
            reply_event_loop
          end
          begin
            @record_total = @parse_file_strategy.record_total
            process_file
          ensure
            @parse_file_strategy.close
          end
        end
      end


      def stop
        @stopped = true
        @acquire_file_strategy.stop
      end

      def join
        thread.join
      end

      def status
        raise "Need to override status method in #{self.class.name}"
      end

      #########
      protected
      #########

      def process_file
        while record = @parse_file_strategy.next_record
          obj = record_to_object(record)
        end
      end

      # Allow extenders to manipulate the file record before sticking it on the queue
      def record_to_object(record)
        record
      end

      # Perform any additional operations on the given responses
      def process_response(obj)
      end

      #######
      private
      #######

      def reply_event_loop
        @reply_session = ModernTimes::JMS::Connection.create_session
        @consumer = @reply_session.consumer(:queue_name => @queue_name)
        @reply_session.start

        while !@stopped && message = @consumer.receive
          @message_mutex.synchronize do
            obj = ModernTimes::JMS.parse_response(message)
            process_response(obj)
            message.acknowledge
          end
          ModernTimes.logger.info {"#{self}::on_message (#{('%.1f' % (@time_track.last_time*1000.0))}ms)"} if ModernTimes::JMS::Connection.log_times?
        end
        @status = 'Exited'
        ModernTimes.logger.info "#{self}: Exiting"
      rescue Exception => e
        @status = "Exited with exception #{e.message}"
        ModernTimes.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
      end
    end
  end
end
