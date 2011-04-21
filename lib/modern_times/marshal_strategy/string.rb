module ModernTimes
  module MarshalStrategy
    module String
      extend self

      def marshal_type
        :text
      end

      def marshal(object)
        object.to_s
      end

      def unmarshal(msg)
        msg
      end
    end
  end
end
