module ModernTimes
  module HornetQ
    module Marshal
      def self.marshal(session, object)
        if object.kind_of? String
          message = session.create_message(::HornetQ::Client::Message::TEXT_TYPE,false)
          message['format'] = 'string'
          message.body = object
        elsif object.kind_of? Hash
          message = session.create_message(::HornetQ::Client::Message::TEXT_TYPE,false)
          message['format'] = 'json'
          message.body = object.to_json
        else
          message = session.create_message(::HornetQ::Client::Message::BYTES_TYPE,false)
          message['format'] = 'ruby'
          message.body = ::Marshal.dump(object)
        end
        return message
      end

      def self.unmarshal(msg)
        case msg['format']
        when 'json'
          return JSON::Parser.new(msg.body).parse
        when 'ruby'
          return ::Marshal.load(msg.body)
        else
          return msg.body
        end
      end
    end
  end
end
