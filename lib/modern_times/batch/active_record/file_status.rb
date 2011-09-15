module ModernTimes::Batch::ActiveRecord
  class FileStatus < ActiveRecord::Base
    set_table_name 'mt_file_statuses'

    def initialize(options)
      @worker_name = options[:worker_name] || raise 'worker_name option not passed for file_status'
    end

    # Resume any previous jobs that were stopped
    def resume?
      false
    end

    def start(file)
      @file           = file
      @pending_hash   = {}
      @fail_array     = []
      @finished_count = 0
    end

    def stop
      return unless @file
      save_yaml = {
          :file           => @file,
          :pending        => @pending_hash,
          :fail           => @fail_array,
          :finished_count => @finished_count
      }
    end

    def finish
      @file = nil
    end

    def start_record(message_id, file_pos)
      @pending_hash[message_id] = file_pos
    end

    def finish_record(message_id)
      @pending_hash.delete(message_id)
      @finished_count += 1
    end

    def fail_record(message_id)
      file_pos = @pending_hash.delete(message_id)
      raise "Invalid message #{message_id}, not in pending_hash" unless file_pos
      @fail_array << file_pos
    end

    def pending_count
      @pending_hash.size
    end

    def failed_count
      @fail_array.size
    end
  end
end
