module ModernTimes
  module Batch
    class AcquireFileStrategy
      def initialize(options)
        @glob         = options[:glob]
        raise "file_options glob value not set" unless @glob
        @poll_time    = (options[:poll_time] || 10.0).to_f
        # Ftp's could be in progress, make sure the file is at least 60 seconds old by default before processing
        @age          = (options[:age] || 60).to_i
        @stopped      = false
      end

      # Returns the next file or nil if stopped
      def next_file
        until @stopped
          Dir.glob(@glob).each do |file|
            unless file.match /\.(processing|completed)$/
              return file if (Time.now - File.mtime(file) > @age)
            end
          end
          @sleep_thread = Thread.current
          sleep @poll_time
        end
        return nil
      end

      def mark_file_as_processing(file)
        new_file = file + '.processing'
        File.rename(file, new_file)
        return new_file
      end

      def complete_file(file)
        file.match(/(.*)\.processing$/) || raise("#{file} is not currently being processed")
        new_file = $1 + '.completed'
        File.rename(file, new_file)
        return new_file
      end

      def stop
        @stopped = true
        @sleep_thread.wakeup if @sleep_thread
      end

    end
  end
end
