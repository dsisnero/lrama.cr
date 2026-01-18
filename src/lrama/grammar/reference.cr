module Lrama
  class Grammar
    struct Reference
      getter type : ::Symbol
      getter name : String?
      getter number : Int32?
      getter index : Int32?
      getter ex_tag : Lexer::Token::Base?
      getter first_column : Int32
      getter last_column : Int32

      def initialize(
        @type : ::Symbol,
        @first_column : Int32,
        @last_column : Int32,
        @name : String? = nil,
        @number : Int32? = nil,
        @index : Int32? = nil,
        @ex_tag : Lexer::Token::Base? = nil,
      )
      end

      def value
        name || number
      end
    end
  end
end
