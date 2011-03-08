module ModernTimes
  module HornetQ
    module MarshalStrategy
      module String
        def marshal(session, object, durable)
          message = session.create_message(::HornetQ::Client::Message::TEXT_TYPE, durable)
          message.body = object.to_s
          message
        end

        def unmarshal(msg)
          msg.body
        end
      end
    end
  end
end
