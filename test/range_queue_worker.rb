class RangeQueueWorker
  attr_reader :results

  def initialize
    @results = []
    @mutex = Mutex.new
  end

  def perform(value)
    @mutex.synchronize do
      @results << value
    end
  end
end