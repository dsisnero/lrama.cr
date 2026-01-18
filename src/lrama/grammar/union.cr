module Lrama
  class Grammar
    class Union
      getter code : Lexer::Token::UserCode
      getter lineno : Int32

      def initialize(@code : Lexer::Token::UserCode, @lineno : Int32)
      end

      def braces_less_code
        code.s_value
      end
    end
  end
end
