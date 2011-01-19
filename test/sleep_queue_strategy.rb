class SleepQueueStrategy
  def initialize(sleep_time_array)
    @sleep_time_array
    @mutex = Mutex.new
    @is_stopped = false
    @session_count = 0
  end

  # Create session_info if necessary
  def create_session
    # Unused in this implementation but we'll use for logging
    @mutex.synchronize do
      @session_count += 1
    end
    return "session #{@session_count}"
  end

  def receive(session_info)
    return nil if @is_stopped
    value = nil
    @mutex.synchronize do
      if @count > @range.last
        if @is_replay
          # Don't clobber cpu
          sleep @replay_sleep
          return nil if @is_stopped
          @count = @range.first
        else
          return nil
        end
      end
      value = @count
      @count += 1
    end
    return value
  end

  def failed(session_info, value)
    ModernTimes.logger.info "Failed for #{session_info} with value #{value}"
  end

  def stop
    @is_stopped = true
  end

  def stopped
    @is_stopped
  end
end