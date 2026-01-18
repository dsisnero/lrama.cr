module Lrama
  class Lexer
    module Token
      class Empty < Base
        def initialize(location : Location)
          super(s_value: "%empty", location: location)
        end
      end
    end
  end
end
