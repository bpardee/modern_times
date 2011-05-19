class BarWorker
  include ModernTimes::JMS::Worker

  def perform(obj)
    puts "#{self}: Received #{obj.inspect} at #{Time.now}"
    sleep 5
  end
end