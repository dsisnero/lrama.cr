module Lrama
  class GrammarParser
    DECLARATION_START = Set(String | Symbol).new([
      "%after-pop-stack",
      "%after-reduce",
      "%after-shift",
      "%after-shift-error-token",
      "%before-reduce",
      "%categories",
      "%code",
      "%define",
      "%destructor",
      "%error-token",
      "%expect",
      "%initial-action",
      "%inline",
      "%lex-param",
      "%locations",
      "%no-stdlib",
      "%nterm",
      "%nonassoc",
      "%param",
      "%parse-param",
      "%precedence",
      "%printer",
      "%require",
      "%right",
      "%rule",
      "%start",
      "%token",
      "%type",
      "%union",
    ])

    @pending_token : Lexer::TokenValue?
    @opening_prec_seen : Bool
    @trailing_prec_seen : Bool
    @code_after_prec : Bool

    def initialize(@lexer : Lexer)
      @grammar = Grammar.new
      @section = :declarations
      @pending_token = nil
      @opening_prec_seen = false
      @trailing_prec_seen = false
      @code_after_prec = false
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
      if @section == :rules
        return if handle_rules_token(token)
      end
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
        if @section == :rules
          capture_epilogue
        else
          advance_section
        end
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
      return true if handle_separator(token_value)

      if token_value == "%rule"
        parse_rule_declaration
        return true
      end
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
                handle_declaration_lists(token_value) ||
                handle_declaration_ident(token_value)
      return handled if handled

      handle_precedence_or_start(token_value)
    end

    private def handle_rules_token(token : Lexer::TokenValue)
      token_value = token[0]
      return true if handle_separator(token_value)

      if token_value == :IDENT_COLON
        parse_rule(token[1].as(Lexer::Token::Ident))
        return true
      end

      if token_value == "%rule"
        parse_rule_declaration
        return true
      end

      handle_declaration_token_anywhere(token_value)
    end

    private def handle_declaration_token_anywhere(token_value : String | Symbol)
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
                handle_declaration_lists(token_value) ||
                handle_declaration_ident(token_value)
      return handled if handled

      handle_precedence_or_start(token_value)
    end

    private def handle_separator(token_value : String | Symbol)
      token_value == ";"
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
      when "%param"
        parse_param_blocks
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

    private def handle_declaration_ident(token_value : String | Symbol)
      case token_value
      when "%after-shift"
        parse_after_hook(:after_shift)
      when "%before-reduce"
        parse_after_hook(:before_reduce)
      when "%after-reduce"
        parse_after_hook(:after_reduce)
      when "%after-shift-error-token"
        parse_after_hook(:after_shift_error_token)
      when "%after-pop-stack"
        parse_after_hook(:after_pop_stack)
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

    private def parse_after_hook(kind : Symbol)
      token = expect_token(:IDENTIFIER)
      value = token[1].s_value
      case kind
      when :after_shift
        @grammar.after_shift = value
      when :before_reduce
        @grammar.before_reduce = value
      when :after_reduce
        @grammar.after_reduce = value
      when :after_shift_error_token
        @grammar.after_shift_error_token = value
      when :after_pop_stack
        @grammar.after_pop_stack = value
      end
    end

    private def reset_precs
      @opening_prec_seen = false
      @trailing_prec_seen = false
      @code_after_prec = false
    end

    private def prec_seen?
      @opening_prec_seen || @trailing_prec_seen
    end

    private def on_action_error(message : String, token : Lexer::Token::Base? = nil)
      location = token ? token.location : @lexer.location
      raise ParseError.new(location.generate_error_message(message))
    end

    private def capture_epilogue
      begin_c_declaration("\\Z")
      token = @lexer.next_token
      if token && token[0] == :C_DECLARATION
        code = token[1].as(Lexer::Token::UserCode)
        @grammar.epilogue = code.code
        @grammar.epilogue_first_lineno = code.location.first_line
      else
        raise ParseError.new("Expected epilogue user code")
      end
      end_c_declaration
      @section = :epilogue
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

    private def parse_rule_declaration
      token = next_token
      raise ParseError.new("Expected rule identifier after %rule") unless token

      inline = false
      if token[0] == "%inline"
        inline = true
        token = next_token
        raise ParseError.new("Expected rule identifier after %inline") unless token
      end

      case token[0]
      when :IDENT_COLON
        raise ParseError.new("Inline rule requires %inline") unless inline
        rule_name = token[1].as(Lexer::Token::Ident).s_value
        expect_token(":")
        rhs_list = parse_parameterized_rhs_list
        @grammar.add_parameterized_rule(
          Grammar::ParameterizedRule.new(rule_name, [] of Lexer::Token::Base, rhs_list, inline: true)
        )
      when :IDENTIFIER
        rule_name = token[1].s_value
        expect_token("(")
        args = parse_rule_args
        expect_token(")")
        tag = nil
        if !inline
          tag_token = next_token
          if tag_token && tag_token[0] == :TAG
            tag = tag_token[1].as(Lexer::Token::Tag)
          else
            unread_token(tag_token) if tag_token
          end
        end
        expect_token(":")
        rhs_list = parse_parameterized_rhs_list
        @grammar.add_parameterized_rule(
          Grammar::ParameterizedRule.new(rule_name, args, rhs_list, tag: tag, inline: inline)
        )
      else
        raise ParseError.new("Expected rule identifier after %rule")
      end

      consume_semicolons
    end

    private def parse_rule_args
      args = [] of Lexer::Token::Base
      token = expect_token(:IDENTIFIER)
      args << token[1]

      loop do
        token = next_token
        break unless token
        break unless token[0] == ","
        token = expect_token(:IDENTIFIER)
        args << token[1]
      end
      unread_token(token) if token
      args
    end

    private def parse_rule(lhs_token : Lexer::Token::Ident)
      alias_name = parse_named_ref
      lhs_token.alias_name = alias_name if alias_name
      expect_token(":")
      builders = parse_rhs_list
      builders.each do |builder|
        builder.lhs = lhs_token
        builder.complete_input
        @grammar.add_rule_builder(builder)
      end
      consume_semicolons
    end

    private def parse_parameterized_rhs_list
      list = [] of Grammar::ParameterizedRhs
      list << parse_parameterized_rhs
      loop do
        token = next_token
        break unless token
        if token[0] == "|"
          list << parse_parameterized_rhs
          next
        end
        unread_token(token)
        break
      end
      list
    end

    private def parse_parameterized_rhs
      reset_precs
      builder = Grammar::ParameterizedRhs.new

      loop do
        token = next_token
        break unless token

        token_value = token[0]
        if rhs_terminator?(token_value)
          unread_token(token)
          break
        end

        handled = handle_parameterized_rhs_token(builder, token)
        unless handled
          unread_token(token)
          break
        end
      end

      builder
    end

    private def parse_rhs_list
      list = [] of Grammar::RuleBuilder
      list << parse_rhs
      loop do
        token = next_token
        break unless token
        if token[0] == "|"
          list << parse_rhs
          next
        end
        unread_token(token)
        break
      end

      list.each do |builder|
        if builder.rhs.size > 1
          empties = builder.rhs.select(Lexer::Token::Empty)
          empties.each do |empty|
            on_action_error("%empty on non-empty rule", empty)
          end
        end
        builder.line ||= @lexer.line - 1
      end

      list
    end

    private def parse_rhs
      reset_precs
      builder = @grammar.create_rule_builder

      loop do
        token = next_token
        break unless token

        token_value = token[0]
        if rhs_terminator?(token_value)
          unread_token(token)
          break
        end

        handled = handle_rhs_token(builder, token)
        unless handled
          unread_token(token)
          break
        end
      end

      builder
    end

    private def handle_parameterized_rhs_token(builder : Grammar::ParameterizedRhs, token : Lexer::TokenValue)
      token_value = token[0]
      return handle_parameterized_rhs_empty(builder, token) if token_value == "%empty"
      return handle_parameterized_rhs_prec(builder, token) if token_value == "%prec"
      return handle_parameterized_rhs_action(builder, token) if token_value == "{"
      if token_value == :IDENTIFIER && peek_token_value == "("
        return handle_parameterized_rhs_instantiate(builder, token[1].as(Lexer::Token::Ident))
      end

      if symbol = symbol_token_from(token)
        return handle_parameterized_rhs_symbol(builder, symbol)
      end

      false
    end

    private def handle_parameterized_rhs_empty(builder : Grammar::ParameterizedRhs, token : Lexer::TokenValue)
      return true if builder.symbols.empty?
      on_action_error("%empty on non-empty rule", token[1].as(Lexer::Token::Base))
    end

    private def handle_parameterized_rhs_prec(builder : Grammar::ParameterizedRhs, token : Lexer::TokenValue)
      on_action_error("multiple %prec in a rule", token[1].as(Lexer::Token::Base)) if prec_seen?
      sym = parse_symbol_required
      if builder.symbols.empty?
        @opening_prec_seen = true
      else
        @trailing_prec_seen = true
      end
      builder.precedence_sym = sym
      true
    end

    private def handle_parameterized_rhs_action(builder : Grammar::ParameterizedRhs, token : Lexer::TokenValue)
      on_action_error("intermediate %prec in a rule", token[1].as(Lexer::Token::Base)) if @trailing_prec_seen
      unread_token(token)
      user_code = parse_action
      named_ref = parse_named_ref
      user_code.alias_name = named_ref if named_ref
      builder.user_code = user_code
      true
    end

    private def handle_parameterized_rhs_instantiate(builder : Grammar::ParameterizedRhs, ident : Lexer::Token::Ident)
      expect_token("(")
      args = parse_parameterized_args
      expect_token(")")
      tag = parse_optional_tag
      builder.symbols << Lexer::Token::InstantiateRule.new(
        ident.s_value,
        location: ident.location,
        args: args,
        lhs_tag: tag
      )
      true
    end

    private def handle_parameterized_rhs_symbol(builder : Grammar::ParameterizedRhs, symbol : Lexer::Token::Base)
      on_action_error("intermediate %prec in a rule", symbol) if @trailing_prec_seen
      suffix = parse_parameterized_suffix
      if suffix
        builder.symbols << Lexer::Token::InstantiateRule.new(
          suffix,
          location: symbol.location,
          args: [symbol]
        )
      else
        named_ref = parse_named_ref
        symbol.alias_name = named_ref if named_ref
        builder.symbols << symbol
      end
      true
    end

    private def handle_rhs_token(builder : Grammar::RuleBuilder, token : Lexer::TokenValue)
      token_value = token[0]
      return handle_rhs_empty(builder, token) if token_value == "%empty"
      return handle_rhs_prec(builder, token) if token_value == "%prec"
      return handle_rhs_action(builder, token) if token_value == "{"
      if token_value == :IDENTIFIER && peek_token_value == "("
        return handle_rhs_instantiate(builder, token[1].as(Lexer::Token::Ident))
      end

      if symbol = symbol_token_from(token)
        return handle_rhs_symbol(builder, symbol)
      end

      false
    end

    private def handle_rhs_empty(builder : Grammar::RuleBuilder, token : Lexer::TokenValue)
      builder.add_rhs(Lexer::Token::Empty.new(location: token[1].as(Lexer::Token::Base).location))
      true
    end

    private def handle_rhs_prec(builder : Grammar::RuleBuilder, token : Lexer::TokenValue)
      on_action_error("multiple %prec in a rule", token[1].as(Lexer::Token::Base)) if prec_seen?
      sym = parse_symbol_required
      if builder.rhs.empty?
        @opening_prec_seen = true
      else
        @trailing_prec_seen = true
      end
      builder.precedence_sym = sym
      true
    end

    private def handle_rhs_action(builder : Grammar::RuleBuilder, token : Lexer::TokenValue)
      on_action_error("intermediate %prec in a rule", token[1].as(Lexer::Token::Base)) if @trailing_prec_seen
      unread_token(token)
      user_code = parse_action
      named_ref = parse_named_ref
      user_code.alias_name = named_ref if named_ref
      tag = parse_optional_tag
      user_code.tag = tag if tag
      builder.user_code = user_code
      true
    end

    private def handle_rhs_instantiate(builder : Grammar::RuleBuilder, ident : Lexer::Token::Ident)
      on_action_error("intermediate %prec in a rule", ident) if @trailing_prec_seen
      expect_token("(")
      args = parse_parameterized_args
      expect_token(")")
      named_ref = parse_named_ref
      tag = parse_optional_tag
      token = Lexer::Token::InstantiateRule.new(
        ident.s_value,
        location: ident.location,
        args: args,
        lhs_tag: tag
      )
      token.alias_name = named_ref if named_ref
      builder.add_rhs(token)
      builder.line ||= ident.first_line
      true
    end

    private def handle_rhs_symbol(builder : Grammar::RuleBuilder, symbol : Lexer::Token::Base)
      on_action_error("intermediate %prec in a rule", symbol) if @trailing_prec_seen
      suffix = parse_parameterized_suffix
      if suffix
        named_ref = parse_named_ref
        tag = parse_optional_tag
        inst = Lexer::Token::InstantiateRule.new(
          suffix,
          location: symbol.location,
          args: [symbol],
          lhs_tag: tag
        )
        inst.alias_name = named_ref if named_ref
        builder.add_rhs(inst)
        builder.line ||= symbol.first_line
      else
        named_ref = parse_named_ref
        symbol.alias_name = named_ref if named_ref
        builder.add_rhs(symbol)
      end
      true
    end

    private def parse_named_ref
      token = next_token
      return unless token
      unless token[0] == "["
        unread_token(token)
        return
      end
      ident = expect_token(:IDENTIFIER)
      expect_token("]")
      ident[1].s_value
    end

    private def parse_action
      token = expect_token("{")
      if prec_seen?
        on_action_error("multiple User_code after %prec", token[1].as(Lexer::Token::Base)) if @code_after_prec
        @code_after_prec = true
      end
      begin_c_declaration("}")
      code_token = expect_token(:C_DECLARATION)[1].as(Lexer::Token::UserCode)
      end_c_declaration
      expect_token("}")
      code_token
    end

    private def parse_parameterized_args
      args = [] of Lexer::Token::Base
      args << parse_parameterized_arg
      loop do
        token = next_token
        break unless token
        if token[0] == ","
          args << parse_parameterized_arg
          next
        end
        unread_token(token)
        break
      end
      args
    end

    private def parse_parameterized_arg
      token = next_token
      raise ParseError.new("Expected symbol in parameterized args") unless token

      if token[0] == :IDENTIFIER && peek_token_value == "("
        ident = token[1].as(Lexer::Token::Ident)
        expect_token("(")
        args = parse_parameterized_args
        expect_token(")")
        return Lexer::Token::InstantiateRule.new(
          ident.s_value,
          location: ident.location,
          args: args
        )
      end

      symbol = symbol_token_from(token)
      raise ParseError.new("Expected symbol in parameterized args") unless symbol

      suffix = parse_parameterized_suffix
      return symbol unless suffix

      Lexer::Token::InstantiateRule.new(
        suffix,
        location: symbol.location,
        args: [symbol]
      )
    end

    private def parse_parameterized_suffix
      token = next_token
      return unless token
      unless token[0] == "?" || token[0] == "+" || token[0] == "*"
        unread_token(token)
        return
      end

      case token[0]
      when "?"
        "option"
      when "+"
        "nonempty_list"
      else
        "list"
      end
    end

    private def parse_optional_tag
      token = next_token
      return unless token
      return token[1].as(Lexer::Token::Tag) if token[0] == :TAG
      unread_token(token)
      nil
    end

    private def parse_symbol_required
      token = next_token
      raise ParseError.new("Expected symbol after %prec") unless token
      symbol = symbol_token_from(token)
      raise ParseError.new("Expected symbol after %prec") unless symbol
      symbol
    end

    private def rhs_terminator?(token_value : String | Symbol)
      return true if token_value == "|"
      return true if token_value == ";"
      return true if token_value == "%%"
      return true if token_value == :IDENT_COLON
      return true if declaration_start?(token_value)
      false
    end

    private def declaration_start?(token_value : String | Symbol)
      DECLARATION_START.includes?(token_value)
    end

    private def consume_semicolons
      token = nil
      loop do
        token = next_token
        break unless token
        break unless token[0] == ";"
      end
      unread_token(token) if token
    end

    private def peek_token_value
      token = next_token
      return unless token
      unread_token(token)
      token[0]
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
