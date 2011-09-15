module ModernTimes
  module Batch
    # Default strategy for parsing a file
    class ParseFileStrategy
      def initialize(file_options)
      end

      # Open the file for processing
      def open(file)
        @file = file
        @fin = File.open(@file, 'r')
        @line_count = 0
      end

      # Goto a specific position in the file.  This strategy uses line_counts.  @fin.seek and @fin.tell would
      # be faster but wouldn't allow the file to be edited if it was formatted incorrectly.
      def file_position=(line_count)
        if @line_count > line_count
          @fin.seek(0)
          @line_count = 0
        end
        next_record while @line_count < line_count
      end

      # Return the current position in the file
      def file_position
        @line_count
      end

      # Read the next record from the file
      def next_record
        @line_count += 1
        @fin.gets
      end

      # Return an estimate of the total records in the file
      def record_total
        # Faster than reading file in ruby but won't count incomplete lines
        %x{wc -l #{@file}}.split.first.to_i
      end

      # Close the file
      def close
        @fin.close
      end
    end
  end
end
