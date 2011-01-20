module ModernTimes
  module Stoppable

    def stop
      @is_stopped = true
    end

    def stopped?
      # Make it return false if it's nil
      !!@is_stopped
    end
  end
end