module Lrama
  class Lexer
    module Token
      class Tag < Base
        def member
          slice = s_value[1, s_value.size - 2]?
          raise "Unexpected Tag format (#{s_value})" unless slice
          slice
        end
      end
    end
  end
end
