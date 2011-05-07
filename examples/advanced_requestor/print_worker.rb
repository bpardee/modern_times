class PrintWorker
  include ModernTimes::JMS::Worker

  virtual_topic 'test_string'

  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
  end
end