class SleepQueueStrategy < BaseQueueStrategy
  def initialize(sleep_time_array)
    @sleep_time_array = sleep_time_array
  end

  def mutexed_receive(session)
    if @count > @range.last
      if @is_replay
        # Don't clobber cpu
        sleep @replay_sleep
        return nil if stopped?
        @count = @range.first
      else
        return nil
      end
    end
    @count += 1
    return @count-1
  end
end