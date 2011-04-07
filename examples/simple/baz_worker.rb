class BazWorker < ModernTimes::JMS::Worker
  include ModernTimes::MarshalStrategy::String
  
  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    sleep 10
  end
end