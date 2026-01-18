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
    getter parameterized_rules : Array(ParameterizedRule)
    getter rule_builders : Array(RuleBuilder)
    property after_shift : String?
    property before_reduce : String?
    property after_reduce : String?
    property after_shift_error_token : String?
    property after_pop_stack : String?
    property epilogue : String?
    property epilogue_first_lineno : Int32?

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
      @parameterized_rules = [] of ParameterizedRule
      @rule_builders = [] of RuleBuilder
      @after_shift = nil
      @before_reduce = nil
      @after_reduce = nil
      @after_shift_error_token = nil
      @after_pop_stack = nil
      @epilogue = nil
      @epilogue_first_lineno = nil
    end

    def add_parameterized_rule(rule : ParameterizedRule)
      @parameterized_rules << rule
    end

    def add_rule_builder(builder : RuleBuilder)
      @rule_builders << builder
    end

    def create_rule_builder
      RuleBuilder.new
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

    class RuleBuilder
      property lhs : Lexer::Token::Base?
      property rhs : Array(Lexer::Token::Base)
      property user_code : Lexer::Token::UserCode?
      property precedence_sym : Lexer::Token::Base?
      property line : Int32?

      def initialize
        @rhs = [] of Lexer::Token::Base
        @lhs = nil
        @user_code = nil
        @precedence_sym = nil
        @line = nil
      end

      def add_rhs(token : Lexer::Token::Base)
        @line ||= token.first_line
        @rhs << token
      end

      def complete_input
      end
    end

    class ParameterizedRule
      getter name : String
      getter parameters : Array(Lexer::Token::Base)
      getter rhs_list : Array(ParameterizedRhs)
      getter tag : Lexer::Token::Tag?
      getter? inline : Bool

      def initialize(
        @name : String,
        @parameters : Array(Lexer::Token::Base),
        @rhs_list : Array(ParameterizedRhs),
        @tag : Lexer::Token::Tag? = nil,
        @inline : Bool = false,
      )
      end
    end

    class ParameterizedRhs
      getter symbols : Array(Lexer::Token::Base)
      property user_code : Lexer::Token::UserCode?
      property precedence_sym : Lexer::Token::Base?

      def initialize
        @symbols = [] of Lexer::Token::Base
        @user_code = nil
        @precedence_sym = nil
      end
    end
  end
end
