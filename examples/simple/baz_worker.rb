class BazWorker 
  include ModernTimes::Worker

  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 10

  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    sleep config.sleep_time
  end
end
