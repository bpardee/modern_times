module ModernTimes
  module MarshalStrategy
    module Ruby
      def marshal_type
        :bytes
      end

      def marshal(object)
        ::Marshal.dump(object)
      end

      def unmarshal(msg)
        msg = ::String.from_java_bytes(msg) unless msg.kind_of?(::String)
        ::Marshal.load(msg)
      end
    end
  end
end
