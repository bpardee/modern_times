require 'modern_times/jms/connection'
require 'modern_times/jms/consumer'
require 'modern_times/jms/publisher'
require 'modern_times/jms/publish_handle'
require 'modern_times/jms/supervisor_mbean'
require 'modern_times/jms/supervisor'
require 'modern_times/jms/worker'
require 'modern_times/jms/request_worker'

module ModernTimes
  module JMS
    def self.same_destination?(options1, options2)
      if options1[:queue_name]
        return options1[:queue_name]  == options2[:queue_name]
      elsif options1[:topic_name]
        return options1[:topic_name]  == options2[:topic_name]
      elsif options1[:virtual_topic_name]
        return options1[:virtual_topic_name]  == options2[:virtual_topic_name]
      elsif options1[:destination]
        return options1[:destination] == options2[:destination]
      else
        return false
      end
    end

    def self.create_message(session, marshaler, object)
      case marshaler.marshal_type
        when :text
          session.create_text_message(marshaler.marshal(object))
        when :bytes
          msg = session.create_bytes_message()
          msg.data = marshaler.marshal(object)
          msg
        else raise "Invalid marshal type: #{marshaler.marshal_type}"
      end
    end
  end
end