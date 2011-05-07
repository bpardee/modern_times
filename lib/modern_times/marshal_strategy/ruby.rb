module ModernTimes
  module MarshalStrategy
    module Ruby
      extend self

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

      MarshalStrategy.register(:ruby => self)
      
    end
  end
end
