require 'modern_times/stoppable'

class BaseQueueStrategy
  include ModernTimes::Stoppable

  def initialize
    @mutex = Mutex.new
    @session_count = 0
  end

  # Create session if necessary
  def create_session
    # Unused in this implementation but we'll use for logging
    @mutex.synchronize do
      @session_count += 1
    end
    return "session #{@session_count}"
  end

  def receive(session)
    nil
  end

  def failed(session, value)
    ModernTimes.logger.info "Failed for #{session} with value #{value}"
  end

  protected
  def mutex
    @mutex
  end
end