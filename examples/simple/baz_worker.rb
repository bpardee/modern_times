class BazWorker 
  include ModernTimes::JMS::Worker
  marshal :string

  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    sleep 10
  end
end