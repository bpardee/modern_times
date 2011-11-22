class BaseRequestWorker
  include ModernTimes::JMS::RequestWorker

  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 0

  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    sleep_time = options[:sleep] && options[:sleep].to_f
    if config.sleep_time > 0.0
      puts "#{self}: Sleeping for #{config.sleep_time} at #{Time.now}"
      sleep config.sleep_time
    end
    super
  end
end
