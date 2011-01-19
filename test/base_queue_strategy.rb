class BaseQueueStrategy
  def initialize
    @mutex = Mutex.new
    @is_stopped = false
    @session_count = 0
  end

  def mutexed_receive(session_info)
    raise 'Override this method'
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
      return mutexed_receive(sesion_info)
    end
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