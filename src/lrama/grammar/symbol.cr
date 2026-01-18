require "set"

module Lrama
  class Grammar
    class Symbol
      property id : Lexer::Token::Base
      property alias_name : String?
      getter number : Int32?
      property number_bitmap : Bitmap::Bitmap?
      property tag : Lexer::Token::Tag?
      property token_id : Int32?
      property nullable : Bool?
      property precedence : Precedence?
      property printer : Printer?
      property destructor : Destructor?
      property error_token : ErrorToken?
      property first_set : Set(Grammar::Symbol)
      property first_set_bitmap : Bitmap::Bitmap?
      getter? term : Bool

      @eof_symbol : Bool = false
      @error_symbol : Bool = false
      @undef_symbol : Bool = false
      @accept_symbol : Bool = false

      def initialize(
        @id : Lexer::Token::Base,
        @term : Bool,
        @alias_name : String? = nil,
        @number : Int32? = nil,
        @tag : Lexer::Token::Tag? = nil,
        @token_id : Int32? = nil,
        @nullable : Bool? = nil,
        @precedence : Precedence? = nil,
        @printer : Printer? = nil,
        @destructor : Destructor? = nil,
        @error_token : ErrorToken? = nil,
      )
        @first_set = Set(Grammar::Symbol).new
        @number_bitmap = @number.try { |value| Bitmap.from_integer(value) }
        @first_set_bitmap = nil
      end

      def number=(value : Int32)
        @number = value
        @number_bitmap = Bitmap.from_integer(value)
      end

      def nterm?
        !term?
      end

      def eof_symbol?
        @eof_symbol
      end

      def error_symbol?
        @error_symbol
      end

      def undef_symbol?
        @undef_symbol
      end

      def accept_symbol?
        @accept_symbol
      end

      def eof_symbol=(value : Bool)
        @eof_symbol = value
      end

      def error_symbol=(value : Bool)
        @error_symbol = value
      end

      def undef_symbol=(value : Bool)
        @undef_symbol = value
      end

      def accept_symbol=(value : Bool)
        @accept_symbol = value
      end

      def midrule?
        return false if term?
        name.includes?("$") || name.includes?("@")
      end

      def name
        id.s_value
      end

      def display_name
        alias_name || name
      end

      def enum_name
        res =
          if accept_symbol?
            "YYACCEPT"
          elsif eof_symbol?
            "YYEOF"
          elsif term? && id.is_a?(Lexer::Token::Char)
            "#{number}#{display_name}"
          elsif term? && id.is_a?(Lexer::Token::Ident)
            name
          elsif midrule?
            "#{number}#{name}"
          elsif nterm?
            name
          else
            raise "Unexpected #{self}"
          end

        "YYSYMBOL_" + res.gsub(/\W+/, "_")
      end

      def comment
        if accept_symbol?
          name
        elsif eof_symbol?
          alias_name
        elsif term? && (value = token_id) && value > 0 && value < 128
          display_name
        elsif midrule?
          name
        else
          display_name
        end
      end
    end
  end
end
