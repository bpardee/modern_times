module ModernTimes
  module MarshalStrategy
    # Should only be used with InMem strategy
    module None
      extend self

      def marshal_type
        :bytes
      end

      def marshal(object)
        object
      end

      def unmarshal(msg)
        msg
      end

      MarshalStrategy.register(:none => self)

    end
  end
end
