class RangeQueueStrategy < BaseQueueStrategy
  def initialize(range, is_replay=false, replay_sleep=1)
    super()
    @range = range
    @is_replay = is_replay
    @replay_sleep
    @count = range.first
  end

  def mutexed_receive(session_info)
    value = nil
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
    return value
  end

  def failed(session_info, value)
    ModernTimes.logger.info "Failed for #{session_info} with value #{value}"
  end

  def stop
    @is_stopped = true
  end
end