module Lrama
  class GrammarParser
    def initialize(@lexer : Lexer)
      @grammar = Grammar.new
      @section = :declarations
    end

    def parse
      while token = @lexer.next_token
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
  end
end
