class ReverseEchoWorker
  include ModernTimes::JMS::RequestWorker
  
  def request(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    if obj =~ /^sleep (.*)/
      sleep $1.to_f
      puts "#{self}: Finished sleeping at #{Time.now}"
    end
    if obj =~ /^Exception/
      raise Exception, 'You requested an exception'
    end
    obj.reverse
  end
end