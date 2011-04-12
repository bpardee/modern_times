module ModernTimes
  module MarshalStrategy
    module BSON
      def marshal_type
        :bytes
      end

      begin
        require 'bson'
        def marshal(object)
          ::BSON.serialize(object).to_s
        end

        def unmarshal(msg)
          ::BSON.deserialize(msg)
        end

      rescue LoadError => e
        def marshal(object)
          raise 'Error: BSON marshaling specified but bson gem has not been installed'
        end

        def unmarshal(msg)
          raise 'Error: BSON marshaling specified but bson gem has not been installed'
        end
      end
    end
  end
end
