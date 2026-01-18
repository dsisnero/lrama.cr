module Lrama
  class Grammar
    class Type
      getter id : Lexer::Token::Base
      getter tag : Lexer::Token::Tag

      def initialize(@id : Lexer::Token::Base, @tag : Lexer::Token::Tag)
      end
    end
  end
end
