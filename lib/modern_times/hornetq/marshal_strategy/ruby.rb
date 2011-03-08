module ModernTimes
  module HornetQ
    module MarshalStrategy
      module Ruby
        def marshal(session, object, durable)
          message = session.create_message(::HornetQ::Client::Message::BYTES_TYPE, durable)
          message.body = ::Marshal.dump(object)
          message
        end

        def unmarshal(msg)
          ::Marshal.load(msg.body)
        end
      end
    end
  end
end
