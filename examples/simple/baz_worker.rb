class BazWorker < ModernTimes::HornetQ::Worker
  include ModernTimes::HornetQ::MarshalStrategy::String
  
  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    sleep 10
  end
end