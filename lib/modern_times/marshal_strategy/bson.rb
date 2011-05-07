module ModernTimes
  module MarshalStrategy
    module BSON
      extend self
      
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

        MarshalStrategy.register(:bson => self)

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
