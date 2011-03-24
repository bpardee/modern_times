class ReverseEchoWorker < ModernTimes::HornetQRequestor::Worker
  include ModernTimes::HornetQ::MarshalStrategy::String
  
  def request(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    if obj =~ /^sleep (.*)/
      sleep $1.to_f
      puts "#{self}: Finished sleeping at #{Time.now}"
    end
    obj.reverse
  end
end