require 'modern_times/marshal_strategy/bson'
require 'modern_times/marshal_strategy/json'
require 'modern_times/marshal_strategy/ruby'
require 'modern_times/marshal_strategy/string'
require 'modern_times/marshal_strategy/yaml'

# Defines some default marshaling strategies for use in marshaling/unmarshaling objects
# written and read via jms.  Implementing classes must define the following methods:
#
#   # Return symbol
#   #  :text  if session.create_text_message should be used to generate the JMS message
#   #  :bytes if session.create_bytes_message should be used to generate the JMS message
#   def marshal_type
#     # Return either :text or :bytes
#     :text
#   end
#
#   # Defines the conversion to wire format by the publisher of the message
#   def marshal(object)
#     # Operate on object and convert to message format
#   end
#
#   # Defines the conversion from wire format by the consumer of the message
#   def unmarshal(msg)
#     # Operate on message to convert it from wire protocol back to object format
#   end

module ModernTimes
  module MarshalStrategy
    def self.find(marshal_option)
      if marshal_option.nil?
        return Ruby
      elsif marshal_option.kind_of? Symbol
        return case marshal_option
                 when :ruby   then Ruby
                 when :string then String
                 when :json   then JSON
                 when :bson   then BSON
                 when :yaml   then YAML
                 else raise "Invalid marshal strategy: #{options[:marshal]}"
               end
      elsif marshal_option.respond_to?(:marshal_type)
        return marshal_option
      else
        raise "Invalid marshal strategy: #{marshal_option}"
      end
    end
  end
end
