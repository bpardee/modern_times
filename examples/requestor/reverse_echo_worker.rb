class ReverseEchoWorker < ModernTimes::JMSRequestor::Worker
  include ModernTimes::JMS::MarshalStrategy::String
  
  def request(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    if obj =~ /^sleep (.*)/
      sleep $1.to_f
      puts "#{self}: Finished sleeping at #{Time.now}"
    end
    obj.reverse
  end
end