module ModernTimes
  module MarshalStrategy
    module String
      def marshal(object)
        object.to_s
      end

      def unmarshal(msg)
        msg
      end
    end
  end
end
