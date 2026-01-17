module Lrama
  class GrammarParser
    @pending_token : Lexer::TokenValue?

    def initialize(@lexer : Lexer)
      @grammar = Grammar.new
      @section = :declarations
      @pending_token = nil
    end

    def parse
      while token = next_token
        handle_token(token)
      end
      @grammar
    end

    private def handle_token(token : Lexer::TokenValue)
      token_value = token[0]
      if token_value == "%{"
        begin_c_declaration("%}")
        capture_c_declaration(:prologue)
        return
      end

      if token_value == "%%"
        advance_section
        return
      end

      if token_value == "{"
        begin_c_declaration("}")
        capture_c_declaration(:inline)
        return
      end

      if @section == :declarations
        case token_value
        when "%require"
          parse_require
          return
        when "%define"
          parse_define
          return
        when "%expect"
          parse_expect
          return
        when "%no-stdlib"
          @grammar.no_stdlib = true
          return
        when "%locations"
          @grammar.locations = true
          return
        end
      end

      @grammar.tokens_for(@section) << token
    end

    private def begin_c_declaration(end_symbol : String)
      @lexer.status = :c_declaration
      @lexer.end_symbol = end_symbol
    end

    private def end_c_declaration
      @lexer.status = :initial
      @lexer.end_symbol = nil
    end

    private def capture_c_declaration(kind : Symbol)
      token = @lexer.next_token
      raise ParseError.new("Unexpected EOF while parsing user code") unless token
      unless token[0] == :C_DECLARATION
        raise ParseError.new("Expected C declaration, got #{token[0]}")
      end

      if kind == :prologue
        @grammar.prologue = token[1].as(Lexer::Token::UserCode).code
        closing = next_token
        if closing
          unless closing[0] == "%}"
            unread_token(closing)
          end
        else
          raise ParseError.new("Expected %} to close prologue")
        end
      else
        @grammar.tokens_for(@section) << token
      end

      end_c_declaration
    end

    private def advance_section
      @section =
        case @section
        when :declarations
          :rules
        when :rules
          :epilogue
        else
          :epilogue
        end
    end

    private def next_token
      if token = @pending_token
        @pending_token = nil
        return token
      end
      @lexer.next_token
    end

    private def unread_token(token : Lexer::TokenValue)
      @pending_token = token
    end

    private def parse_require
      expect_token(:STRING)
      @grammar.required = true
    end

    private def parse_expect
      token = expect_token(:INTEGER)
      value = token[1].as(Lexer::Token::Int).value
      @grammar.expect = value
    end

    private def parse_define
      variable_token = expect_token(:IDENTIFIER)
      variable = variable_token[1].s_value
      token = next_token
      if token.nil?
        @grammar.define[variable] = nil
        return
      end

      case token[0]
      when "{"
        value_token = expect_value_token
        expect_token("}")
        @grammar.define[variable] = value_token[1].s_value
      when :IDENTIFIER, :STRING
        @grammar.define[variable] = token[1].s_value
      else
        unread_token(token)
        @grammar.define[variable] = nil
      end
    end

    private def expect_value_token
      token = next_token
      raise ParseError.new("Expected value for %define") unless token
      unless token[0] == :IDENTIFIER || token[0] == :STRING
        raise ParseError.new("Expected value for %define")
      end
      token
    end

    private def expect_token(kind : Symbol | String)
      token = next_token
      raise ParseError.new("Expected #{kind}") unless token
      return token if token[0] == kind
      raise ParseError.new("Expected #{kind}, got #{token[0]}")
    end
  end
end
