class BarWorker
  include ModernTimes::JMS::Worker
  marshal :bson

  def perform(obj)
    puts "#{self}: Received #{obj.inspect} at #{Time.now}"
    sleep 5
  end
end