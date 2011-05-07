class BaseRequestWorker
  include ModernTimes::JMS::RequestWorker

  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    sleep_time = options[:sleep] && options[:sleep].to_f
    if sleep_time && sleep_time > 0.0
      puts "#{self}: Sleeping for #{sleep_time} at #{Time.now}"
      sleep sleep_time
    end
    super
  end
end