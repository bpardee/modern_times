class BarWorker
  include ModernTimes::JMS::Worker

  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 5

  def perform(obj)
    puts "#{self}: Received #{obj.inspect} at #{Time.now}"
    sleep config.sleep_time
  end
end
