module ModernTimes
  module HornetQ
    module MarshalStrategy
      module JSON
        def marshal(session, object, durable)
          message = session.create_message(::HornetQ::Client::Message::TEXT_TYPE, durable)
          message.body = object.to_json
          message
        end

        def unmarshal(msg)
          JSON::Parser.new(msg.body).parse
        end
      end
    end
  end
end
