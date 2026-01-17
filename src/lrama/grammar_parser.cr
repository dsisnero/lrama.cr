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
      return if handle_section_token(token)
      return if handle_inline_code(token)
      return if handle_declaration_token(token)
      @grammar.tokens_for(@section) << token
    end

    private def handle_section_token(token : Lexer::TokenValue)
      token_value = token[0]
      if token_value == "%{"
        begin_c_declaration("%}")
        capture_c_declaration(:prologue)
        return true
      end
      if token_value == "%%"
        advance_section
        return true
      end
      false
    end

    private def handle_inline_code(token : Lexer::TokenValue)
      return false unless token[0] == "{"
      begin_c_declaration("}")
      capture_c_declaration(:inline)
      true
    end

    private def handle_declaration_token(token : Lexer::TokenValue)
      return false unless @section == :declarations

      token_value = token[0]
      if token_value == "%no-stdlib"
        @grammar.no_stdlib = true
        return true
      end
      if token_value == "%locations"
        @grammar.locations = true
        return true
      end

      handled = handle_declaration_with_param(token_value) ||
                handle_declaration_without_param(token_value) ||
                handle_declaration_lists(token_value)
      return handled if handled

      handle_precedence_or_start(token_value)
    end

    private def handle_declaration_with_param(token_value : String | Symbol)
      case token_value
      when "%union"
        parse_union
      when "%destructor"
        parse_code_declaration(@grammar.destructors)
      when "%printer"
        parse_code_declaration(@grammar.printers)
      when "%error-token"
        parse_code_declaration(@grammar.error_tokens)
      when "%lex-param"
        parse_param_assignment(:lex_param)
      when "%parse-param"
        parse_param_assignment(:parse_param)
      when "%initial-action"
        parse_initial_action
      when "%code"
        parse_percent_code
      else
        return false
      end
      true
    end

    private def handle_declaration_without_param(token_value : String | Symbol)
      case token_value
      when "%require"
        parse_require
      when "%define"
        parse_define
      when "%expect"
        parse_expect
      else
        return false
      end
      true
    end

    private def handle_declaration_lists(token_value : String | Symbol)
      case token_value
      when "%token"
        parse_token_declarations
      when "%type"
        parse_type_declarations
      when "%nterm"
        parse_nterm_declarations
      else
        return false
      end
      true
    end

    private def handle_precedence_or_start(token_value : String | Symbol)
      case token_value
      when "%left", "%right", "%precedence", "%nonassoc"
        parse_precedence_kind(token_value.as(String))
      when "%start"
        parse_start
      else
        return false
      end
      true
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

    private def parse_start
      token = expect_token(:IDENTIFIER)
      @grammar.start_symbol = token[1].s_value
    end

    private def parse_union
      @grammar.union_code = parse_param_block
    end

    private def parse_percent_code
      id_token = expect_token(:IDENTIFIER)
      code = parse_param_block
      @grammar.percent_codes << Grammar::PercentCode.new(id_token[1].s_value, code)
    end

    private def parse_code_declaration(target : Array(Grammar::CodeDeclaration))
      code = parse_param_block
      targets = parse_ident_or_tags
      target << Grammar::CodeDeclaration.new(targets, code) unless targets.empty?
    end

    private def parse_param_assignment(kind : Symbol)
      params = parse_param_blocks
      return if params.empty?

      value = params.last.code
      if kind == :lex_param
        @grammar.lex_param = value
      else
        @grammar.parse_param = value
      end
    end

    private def parse_initial_action
      @grammar.initial_action = parse_param_block
    end

    private def parse_type_declarations
      parse_symbol_declarations(@grammar.type_declarations)
    end

    private def parse_nterm_declarations
      parse_symbol_declarations(@grammar.nterm_declarations)
    end

    private def parse_precedence_kind(token_value : String)
      kind =
        case token_value
        when "%left"
          :left
        when "%right"
          :right
        when "%precedence"
          :precedence
        else
          :nonassoc
        end
      parse_precedence_declarations(kind)
    end

    private def parse_param_blocks
      params = [] of Lexer::Token::UserCode
      loop do
        token = next_token
        break unless token

        if token[0] == "{"
          unread_token(token)
          params << parse_param_block
          next
        end

        unread_token(token)
        break
      end
      params
    end

    private def parse_param_block
      expect_token("{")
      begin_c_declaration("}")
      code_token = expect_token(:C_DECLARATION)[1].as(Lexer::Token::UserCode)
      end_c_declaration
      expect_token("}")
      code_token
    end

    private def parse_ident_or_tags
      targets = [] of Lexer::Token::Base
      loop do
        token = next_token
        break unless token

        if token[0] == :TAG
          targets << token[1].as(Lexer::Token::Tag)
          next
        end

        if symbol = symbol_token_from(token)
          targets << symbol
          next
        end

        unread_token(token)
        break
      end
      targets
    end

    private def parse_token_declarations
      current_tag = nil
      loop do
        token = next_token
        break unless token

        if token[0] == :TAG
          current_tag = token[1].as(Lexer::Token::Tag)
          next
        end

        if id_token = id_token_from(token)
          token_id = parse_optional_integer
          alias_name = parse_optional_alias
          @grammar.token_declarations << Grammar::TokenDeclaration.new(
            id: id_token,
            token_id: token_id,
            alias_name: alias_name,
            tag: current_tag
          )
          next
        end

        unread_token(token)
        break
      end
    end

    private def parse_optional_integer
      token = next_token
      return unless token
      if token[0] == :INTEGER
        token[1].as(Lexer::Token::Int).value
      else
        unread_token(token)
        nil
      end
    end

    private def parse_optional_alias
      token = next_token
      return unless token
      if token[0] == :STRING
        token[1].s_value
      else
        unread_token(token)
        nil
      end
    end

    private def parse_symbol_declarations(target : Array(Grammar::SymbolGroup))
      loop do
        token = next_token
        break unless token

        if token[0] == :TAG
          tag = token[1].as(Lexer::Token::Tag)
          tokens = parse_symbol_list
          target << Grammar::SymbolGroup.new(tag, tokens) unless tokens.empty?
          next
        end

        if symbol = symbol_token_from(token)
          tokens = [symbol] + parse_symbol_list
          target << Grammar::SymbolGroup.new(nil, tokens)
          next
        end

        unread_token(token)
        break
      end
    end

    private def parse_symbol_list
      tokens = [] of Lexer::Token::Base
      loop do
        token = next_token
        break unless token

        if token[0] == :TAG
          unread_token(token)
          break
        end

        if symbol = symbol_token_from(token)
          tokens << symbol
          next
        end

        unread_token(token)
        break
      end
      tokens
    end

    private def parse_precedence_declarations(kind : Symbol)
      loop do
        token = next_token
        break unless token

        if token[0] == :TAG
          tag = token[1].as(Lexer::Token::Tag)
          tokens = parse_id_list
          @grammar.precedence_declarations << Grammar::PrecedenceDeclaration.new(kind, tag, tokens) unless tokens.empty?
          next
        end

        if id = id_token_from(token)
          tokens = [id] + parse_id_list
          @grammar.precedence_declarations << Grammar::PrecedenceDeclaration.new(kind, nil, tokens)
          next
        end

        unread_token(token)
        break
      end
    end

    private def parse_id_list
      tokens = [] of Lexer::Token::Base
      loop do
        token = next_token
        break unless token

        if token[0] == :TAG
          unread_token(token)
          break
        end

        if id = id_token_from(token)
          tokens << id
          next
        end

        unread_token(token)
        break
      end
      tokens
    end

    private def symbol_token_from(token : Lexer::TokenValue)
      return token[1] if token[0] == :IDENTIFIER || token[0] == :CHARACTER
      if token[0] == :STRING
        return Lexer::Token::Ident.new(token[1].s_value, token[1].location)
      end
    end

    private def id_token_from(token : Lexer::TokenValue)
      return token[1] if token[0] == :IDENTIFIER || token[0] == :CHARACTER
    end
  end
end
