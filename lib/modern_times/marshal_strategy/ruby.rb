module ModernTimes
  module MarshalStrategy
    module Ruby
      def marshal_type
        :text
      end

      def marshal(object)
        ::Marshal.dump(object)
      end

      def unmarshal(msg)
        ::Marshal.load(msg)
      end
    end
  end
end
