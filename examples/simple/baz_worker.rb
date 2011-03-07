class BazWorker < ModernTimes::HornetQ::Worker
  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    sleep 10
  end
end