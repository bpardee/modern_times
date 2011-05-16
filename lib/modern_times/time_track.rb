require 'benchmark'

module ModernTimes
  class TimeTrack
    attr_reader :total_count, :time_count, :max_time, :last_time

    def initialize
      @mutex = Mutex.new
      @total_count = 0
      @last_time   = 0.0
      reset
    end

    def reset
      @mutex.synchronize do
        @time_count  = 0
        @min_time    = nil
        @max_time    = 0.0
        @total_time  = 0.0
      end
    end

    def perform
      answer = nil
      @last_time = Benchmark.realtime { answer = yield }
      @mutex.synchronize do
        @total_count += 1
        @time_count  += 1
        @total_time  += @last_time
        @min_time = @last_time if !@min_time || @last_time < @min_time
        @max_time = @last_time if @last_time > @max_time
      end
      answer
    end

    def total_time
      @mutex.synchronize do
        [@time_count, @total_time]
      end
    end

    def min_time
      @min_time || 0.0
    end

    def avg_time
      @mutex.synchronize do
        return 0.0 if @time_count == 0
        @total_time / @time_count
      end
    end

    # Return the total time and reset it.  Kind of hackish but allows for tools like
    # Hyperic to poll these values in an xml attribute setup.
    def total_time_reset
      @mutex.synchronize do
        retval = [@time_count, @total_time]
        @time_count = 0
        @total_time = 0.0
        return retval
      end
    end

    def min_time_reset
      @mutex.synchronize do
        val = @min_time || 0.0
        @min_time = nil
        return val
      end
    end

    def max_time_reset
      @mutex.synchronize do
        val = @max_time
        @max_time = 0.0
        return val
      end
    end

    def to_s
      "sample=#{@time_count} min=#{('%.1f' % (1000*min_time))}ms max=#{('%.1f' % (1000*max_time))}ms avg=#{('%.1f' % (1000*avg_time))}ms"
    end
  end
end
