module Lrama
  class Lexer
    module Token
      class Int < Base
        def value
          s_value.to_i
        end
      end
    end
  end
end
