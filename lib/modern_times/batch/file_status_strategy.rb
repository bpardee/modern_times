require 'tmpdir'

module ModernTimes
  module Batch
    class FileStatusStrategy

      attr_reader :finished_count

      if defined?(Rails) && defined?(Rails.root)
        @@persist_dir = File.join(Rails.root, 'log', 'modern_times')
      else
        @@persist_dir = File.join(Dir.tmpdir, 'modern_times')
      end

      def self.persist_dir
        @@persist_dir
      end

      def self.persist_dir=(dir)
        @@persist_dir = dir
      end

      def initialize(options)
        @worker_name = options[:worker_name]
        @dir = options[:persist_dir] || @@persist_dir
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

      #######
      private
      #######

      def save
        persist_file =
      end
    end
  end
end
