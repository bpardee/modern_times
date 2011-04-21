module ModernTimes
  module MarshalStrategy
    module JSON
      extend self

      def marshal_type
        :text
      end

      begin
        require 'json'
        def marshal(object)
          object.to_json
        end

        def unmarshal(msg)
          ::JSON::Parser.new(msg).parse
        end
      rescue LoadError => e
        def marshal(object)
          raise 'Error: JSON marshaling specified but json gem has not been installed'
        end

        def unmarshal(msg)
          raise 'Error: JSON marshaling specified but json gem has not been installed'
        end
      end
    end
  end
end
