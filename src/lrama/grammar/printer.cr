module Lrama
  class Grammar
    class Printer
      getter ident_or_tags : Array(Lexer::Token::Base)
      getter token_code : Lexer::Token::UserCode
      getter lineno : Int32

      def initialize(
        @ident_or_tags : Array(Lexer::Token::Base),
        @token_code : Lexer::Token::UserCode,
        @lineno : Int32,
      )
      end
    end
  end
end
