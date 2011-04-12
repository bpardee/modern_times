require 'modern_times/jms/connection'
require 'modern_times/jms/publisher'
require 'modern_times/jms/supervisor_mbean'
require 'modern_times/jms/supervisor'
require 'modern_times/jms/worker'

module ModernTimes
  module JMS
    def self.same_destination?(options1, options2)
      if options1[:queue_name]
        return options1[:queue_name]  == options2[:queue_name]
      elsif options1[:topic_name]
        return options1[:topic_name]  == options2[:topic_name]
      elsif options1[:destination]
        return options1[:destination] == options2[:destination]
      else
        return false
      end
    end
  end
end