module Lrama
  class Grammar
    getter declarations_tokens : Array(Lexer::TokenValue)
    getter rules_tokens : Array(Lexer::TokenValue)
    getter epilogue_tokens : Array(Lexer::TokenValue)
    property prologue : String?
    property? required : Bool
    property define : Hash(String, String?)
    property expect : Int32?
    property? no_stdlib : Bool
    property? locations : Bool
    getter token_declarations : Array(TokenDeclaration)
    getter type_declarations : Array(SymbolGroup)
    getter nterm_declarations : Array(SymbolGroup)
    getter precedence_declarations : Array(PrecedenceDeclaration)
    property start_symbol : String?
    property union_code : Lexer::Token::UserCode?
    property lex_param : String?
    property parse_param : String?
    property initial_action : Lexer::Token::UserCode?
    getter percent_codes : Array(PercentCode)
    getter printers : Array(CodeDeclaration)
    getter destructors : Array(CodeDeclaration)
    getter error_tokens : Array(CodeDeclaration)

    def initialize
      @declarations_tokens = [] of Lexer::TokenValue
      @rules_tokens = [] of Lexer::TokenValue
      @epilogue_tokens = [] of Lexer::TokenValue
      @prologue = nil
      @required = false
      @define = {} of String => String?
      @expect = nil
      @no_stdlib = false
      @locations = false
      @token_declarations = [] of TokenDeclaration
      @type_declarations = [] of SymbolGroup
      @nterm_declarations = [] of SymbolGroup
      @precedence_declarations = [] of PrecedenceDeclaration
      @start_symbol = nil
      @union_code = nil
      @lex_param = nil
      @parse_param = nil
      @initial_action = nil
      @percent_codes = [] of PercentCode
      @printers = [] of CodeDeclaration
      @destructors = [] of CodeDeclaration
      @error_tokens = [] of CodeDeclaration
    end

    def tokens_for(section : Symbol)
      case section
      when :declarations
        declarations_tokens
      when :rules
        rules_tokens
      when :epilogue
        epilogue_tokens
      else
        raise "Unknown section: #{section}"
      end
    end

    struct TokenDeclaration
      getter id : Lexer::Token::Base
      getter token_id : Int32?
      getter alias_name : String?
      getter tag : Lexer::Token::Tag?

      def initialize(
        @id : Lexer::Token::Base,
        @token_id : Int32? = nil,
        @alias_name : String? = nil,
        @tag : Lexer::Token::Tag? = nil,
      )
      end
    end

    struct SymbolGroup
      getter tag : Lexer::Token::Tag?
      getter tokens : Array(Lexer::Token::Base)

      def initialize(@tag : Lexer::Token::Tag?, @tokens : Array(Lexer::Token::Base))
      end
    end

    struct PrecedenceDeclaration
      getter kind : Symbol
      getter tag : Lexer::Token::Tag?
      getter tokens : Array(Lexer::Token::Base)

      def initialize(@kind : Symbol, @tag : Lexer::Token::Tag?, @tokens : Array(Lexer::Token::Base))
      end
    end

    struct PercentCode
      getter id : String
      getter code : Lexer::Token::UserCode

      def initialize(@id : String, @code : Lexer::Token::UserCode)
      end
    end

    struct CodeDeclaration
      getter targets : Array(Lexer::Token::Base)
      getter code : Lexer::Token::UserCode

      def initialize(@targets : Array(Lexer::Token::Base), @code : Lexer::Token::UserCode)
      end
    end
  end
end
