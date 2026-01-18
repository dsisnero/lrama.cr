module Lrama
  class Grammar
    class Destructor
      getter ident_or_tags : Array(Lexer::Token::Base)
      getter token_code : Lexer::Token::UserCode
      getter lineno : Int32

      def initialize(
        @ident_or_tags : Array(Lexer::Token::Base),
        @token_code : Lexer::Token::UserCode,
        @lineno : Int32,
      )
      end

      def translated_code(tag : Lexer::Token::Tag)
        Code::DestructorCode.new(:destructor, token_code, tag).translated_code
      end
    end
  end
end
