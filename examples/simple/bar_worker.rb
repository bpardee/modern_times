class BarWorker < ModernTimes::HornetQ::Worker
  def perform(obj)
    puts "#{self}: Received #{obj.inspect} at #{Time.now}"
    sleep 5
  end
end