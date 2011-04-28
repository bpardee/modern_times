module ModernTimes
  module MarshalStrategy
    module YAML
      extend self

      def marshal_type
        :text
      end

      def marshal(object)
        object.to_yaml
      end

      def unmarshal(msg)
        ::YAML.load(msg)
      end
    end
  end
end
