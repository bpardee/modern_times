module ModernTimes
  module MarshalStrategy
    module JSON
      def marshal(object)
        object.to_json
      end

      def unmarshal(msg)
        JSON::Parser.new(msg).parse
      end
    end
  end
end
