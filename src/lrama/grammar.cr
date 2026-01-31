require "set"
require "./bitmap"
require "./grammar/binding"
require "./grammar/counter"
require "./grammar/auxiliary"
require "./grammar/code"
require "./grammar/precedence"
require "./grammar/printer"
require "./grammar/destructor"
require "./grammar/error_token"
require "./grammar/inline"
require "./grammar/parameterized"
require "./grammar/rule"
require "./grammar/rule_builder"
require "./grammar/type"
require "./grammar/union"
require "./grammar/symbol"
require "./grammar/symbols"

module Lrama
  class Grammar
    @internal_location : Lexer::Location?
    @eof_symbol : Grammar::Symbol?
    @error_symbol : Grammar::Symbol?
    @undef_symbol : Grammar::Symbol?
    @accept_symbol : Grammar::Symbol?
    getter declarations_tokens : Array(Lexer::TokenValue)
    getter rules_tokens : Array(Lexer::TokenValue)
    getter epilogue_tokens : Array(Lexer::TokenValue)
    property prologue : String?
    property prologue_first_lineno : Int32?
    property? required : Bool
    property define : Hash(String, String?)
    property expect : Int32?
    property? no_stdlib : Bool
    property? locations : Bool
    getter token_declarations : Array(TokenDeclaration)
    getter type_declarations : Array(SymbolGroup)
    getter nterm_declarations : Array(SymbolGroup)
    getter precedence_declarations : Array(PrecedenceDeclaration)
    getter types : Array(Type)
    getter precedences : Array(Precedence)
    property start_symbol : String?
    property union_code : Lexer::Token::UserCode?
    property lex_param : String?
    property parse_param : String?
    property initial_action : Lexer::Token::UserCode?
    getter percent_codes : Array(PercentCode)
    getter printers : Array(CodeDeclaration)
    getter destructors : Array(CodeDeclaration)
    getter error_tokens : Array(CodeDeclaration)
    getter symbols_resolver : Grammar::Symbols::Resolver
    getter parameterized_resolver : Grammar::Parameterized::Resolver
    getter parameterized_rules : Array(Parameterized::Rule)
    getter rule_builders : Array(Grammar::RuleBuilder)
    getter rules : Array(Grammar::Rule)
    property after_shift : String?
    property before_reduce : String?
    property after_reduce : String?
    property after_shift_error_token : String?
    property after_pop_stack : String?
    property epilogue : String?
    property epilogue_first_lineno : Int32?
    property lexer_spec : LexerSpec?
    getter aux : Grammar::Auxiliary
    property union : Grammar::Union?
    getter sym_to_rules : Hash(Int32, Array(Grammar::Rule))
    getter rule_counter : Grammar::Counter
    getter midrule_action_counter : Grammar::Counter
    getter eof_symbol : Grammar::Symbol?
    getter error_symbol : Grammar::Symbol?
    getter undef_symbol : Grammar::Symbol?
    getter accept_symbol : Grammar::Symbol?

    def initialize
      @declarations_tokens = [] of Lexer::TokenValue
      @rules_tokens = [] of Lexer::TokenValue
      @epilogue_tokens = [] of Lexer::TokenValue
      @prologue = nil
      @prologue_first_lineno = nil
      @required = false
      @define = {} of String => String?
      @expect = nil
      @no_stdlib = false
      @locations = false
      @token_declarations = [] of TokenDeclaration
      @type_declarations = [] of SymbolGroup
      @nterm_declarations = [] of SymbolGroup
      @precedence_declarations = [] of PrecedenceDeclaration
      @types = [] of Type
      @precedences = [] of Precedence
      @start_symbol = nil
      @union_code = nil
      @lex_param = nil
      @parse_param = nil
      @initial_action = nil
      @percent_codes = [] of PercentCode
      @printers = [] of CodeDeclaration
      @destructors = [] of CodeDeclaration
      @error_tokens = [] of CodeDeclaration
      @symbols_resolver = Grammar::Symbols::Resolver.new
      @parameterized_resolver = Grammar::Parameterized::Resolver.new
      @parameterized_rules = [] of Parameterized::Rule
      @rule_builders = [] of Grammar::RuleBuilder
      @rules = [] of Grammar::Rule
      @after_shift = nil
      @before_reduce = nil
      @after_reduce = nil
      @after_shift_error_token = nil
      @after_pop_stack = nil
      @epilogue = nil
      @epilogue_first_lineno = nil
      @lexer_spec = nil
      @aux = Grammar::Auxiliary.new
      @union = nil
      @sym_to_rules = {} of Int32 => Array(Grammar::Rule)
      @rule_counter = Grammar::Counter.new(0)
      @midrule_action_counter = Grammar::Counter.new(1)
      @internal_location = nil
      @eof_symbol = nil
      @error_symbol = nil
      @undef_symbol = nil
      @accept_symbol = nil
      append_special_symbols
    end

    def add_parameterized_rule(rule : Parameterized::Rule)
      @parameterized_rules << rule
      @parameterized_resolver.add_rule(rule)
    end

    def add_rule_builder(builder : Grammar::RuleBuilder)
      @rule_builders << builder
    end

    def create_rule_builder(rule_counter : Grammar::Counter, midrule_action_counter : Grammar::Counter)
      RuleBuilder.new(rule_counter, midrule_action_counter, @parameterized_resolver)
    end

    def add_type(id : Lexer::Token::Base, tag : Lexer::Token::Tag?)
      return unless tag
      @types << Type.new(id, tag)
    end

    def add_left(sym : Grammar::Symbol, precedence : Int32, s_value : String, lineno : Int32)
      set_precedence(sym, Precedence.new(sym, s_value, :left, precedence, lineno))
    end

    def add_right(sym : Grammar::Symbol, precedence : Int32, s_value : String, lineno : Int32)
      set_precedence(sym, Precedence.new(sym, s_value, :right, precedence, lineno))
    end

    def add_precedence(sym : Grammar::Symbol, precedence : Int32, s_value : String, lineno : Int32)
      set_precedence(sym, Precedence.new(sym, s_value, :precedence, precedence, lineno))
    end

    def add_nonassoc(sym : Grammar::Symbol, precedence : Int32, s_value : String, lineno : Int32)
      set_precedence(sym, Precedence.new(sym, s_value, :nonassoc, precedence, lineno))
    end

    private def set_precedence(sym : Grammar::Symbol, precedence : Precedence)
      sym.precedence = precedence
      @precedences << precedence
    end

    def tokens_for(section : ::Symbol)
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

    def symbols
      symbols_resolver.symbols
    end

    def nterms
      symbols_resolver.nterms
    end

    def terms
      symbols_resolver.terms
    end

    def add_nterm(id : Lexer::Token::Base, alias_name : String? = nil, tag : Lexer::Token::Tag? = nil)
      symbols_resolver.add_nterm(id, alias_name, tag)
    end

    def add_term(
      id : Lexer::Token::Base,
      alias_name : String? = nil,
      tag : Lexer::Token::Tag? = nil,
      token_id : Int32? = nil,
      replace : Bool = false,
    )
      symbols_resolver.add_term(id, alias_name, tag, token_id, replace)
    end

    def find_term_by_s_value(s_value : String)
      symbols_resolver.find_term_by_s_value(s_value)
    end

    def find_symbol_by_s_value!(s_value : String)
      symbols_resolver.find_symbol_by_s_value!(s_value)
    end

    def find_symbol_by_id!(id : Lexer::Token::Base)
      symbols_resolver.find_symbol_by_id!(id)
    end

    def find_symbol_by_number!(number : Int32)
      symbols_resolver.find_symbol_by_number!(number)
    end

    def token_to_symbol(token : Lexer::Token::Base)
      symbols_resolver.token_to_symbol(token)
    end

    def fill_symbol_number
      symbols_resolver.fill_symbol_number
    end

    def sort_symbols_by_number!
      symbols_resolver.sort_by_number!
    end

    def append_special_symbols
      term = add_term(
        Lexer::Token::Ident.new("YYEOF", location: internal_location),
        "\"end of file\"",
        nil,
        0
      )
      term.number = 0
      term.eof_symbol = true
      @eof_symbol = term

      term = add_term(
        Lexer::Token::Ident.new("YYerror", location: internal_location),
        "error"
      )
      term.number = 1
      term.error_symbol = true
      @error_symbol = term

      term = add_term(
        Lexer::Token::Ident.new("YYUNDEF", location: internal_location),
        "\"invalid token\""
      )
      term.number = 2
      term.undef_symbol = true
      @undef_symbol = term

      term = add_nterm(Lexer::Token::Ident.new("$accept", location: internal_location))
      term.accept_symbol = true
      @accept_symbol = term
    end

    def eof_symbol!
      @eof_symbol || raise "EOF symbol not initialized"
    end

    def error_symbol!
      @error_symbol || raise "Error symbol not initialized"
    end

    def undef_symbol!
      @undef_symbol || raise "Undefined symbol not initialized"
    end

    def accept_symbol!
      @accept_symbol || raise "Accept symbol not initialized"
    end

    def resolve_inline_rules
      while @rule_builders.any?(&.has_inline_rules?)
        @rule_builders = @rule_builders.flat_map do |builder|
          if builder.has_inline_rules?
            Inline::Resolver.new(builder).resolve
          else
            [builder]
          end
        end
      end
    end

    def normalize_rules
      add_accept_rule
      setup_rules
      @rule_builders.each do |builder|
        builder.rules.each do |rule|
          lhs_token = rule._lhs
          add_nterm(lhs_token, nil, rule.lhs_tag) if lhs_token
          @rules << rule
        end
      end
      @rules.sort_by! { |rule| rule.id || 0 }
    end

    def setup_rules
      @rule_builders.each(&.setup_rules)
    end

    def add_accept_rule
      start = start_rule_token
      lineno = start.try(&.line) || 0
      accept = @accept_symbol
      eof = @eof_symbol
      raise "Special symbols not initialized" unless accept && eof
      @rules << Rule.new(
        id: @rule_counter.increment,
        _lhs: accept.id,
        _rhs: [start, eof.id],
        token_code: nil,
        lineno: lineno
      )
    end

    def collect_symbols
      @rules.flat_map(&._rhs).each do |token|
        case token
        when Lexer::Token::Char
          add_term(token)
        when Lexer::Token::Base
          # skip
        else
          raise "Unknown class: #{token}"
        end
      end
    end

    def set_lhs_and_rhs
      @rules.each do |rule|
        lhs_token = rule._lhs
        next unless lhs_token
        rule.lhs = token_to_symbol(lhs_token)
        rule.rhs = rule._rhs.map { |token| token_to_symbol(token) }
      end
    end

    def fill_default_precedence
      @rules.each do |rule|
        next if rule.precedence_sym
        precedence_sym = nil
        rule.rhs.each do |sym|
          precedence_sym = sym if sym.term?
        end
        rule.precedence_sym = precedence_sym
      end
    end

    def fill_symbols
      fill_symbol_number
      symbols_resolver.fill_nterm_type(@types)
      symbols_resolver.fill_printer(build_printers)
      symbols_resolver.fill_destructor(build_destructors)
      symbols_resolver.fill_error_token(build_error_tokens)
      sort_symbols_by_number!
    end

    def prepend_parameterized_rules(rules : Array(Parameterized::Rule))
      @parameterized_resolver.rules = rules + @parameterized_resolver.rules
      @parameterized_rules = rules + @parameterized_rules
    end

    def prepare
      resolve_inline_rules
      normalize_rules
      collect_symbols
      set_lhs_and_rhs
      fill_default_precedence
      fill_symbols
      fill_sym_to_rules
      sort_precedence
      compute_nullable
      compute_first_set
      set_locations
    end

    def validate!
      symbols_resolver.validate!
      validate_no_precedence_for_nterm!
      validate_rule_lhs_is_nterm!
      validate_duplicated_precedence!
    end

    def find_rules_by_symbol!(sym : Grammar::Symbol)
      find_rules_by_symbol(sym) || raise "Rules for #{sym} not found"
    end

    def find_rules_by_symbol(sym : Grammar::Symbol)
      number = sym.number
      return unless number
      @sym_to_rules[number]?
    end

    def select_rules_by_s_value(value : String)
      @rules.select { |rule| rule.lhs.try(&.id.s_value) == value }
    end

    def unique_rule_s_values
      values = @rules.compact_map { |rule| rule.lhs.try(&.id.s_value) }
      values.uniq!
      values
    end

    def ielr_defined?
      @define.has_key?("lr.type") && @define["lr.type"] == "ielr"
    end

    def fill_sym_to_rules
      @rules.each do |rule|
        lhs = rule.lhs
        next unless lhs
        number = lhs.number
        next unless number
        @sym_to_rules[number] ||= [] of Rule
        @sym_to_rules[number] << rule
      end
    end

    def validate_no_precedence_for_nterm!
      errors = [] of String
      nterms.each do |nterm|
        precedence = nterm.precedence
        next unless precedence
        errors << "[BUG] Precedence #{nterm.name} (line: #{precedence.lineno}) is defined for nonterminal symbol (line: #{nterm.id.first_line}). Precedence can be defined for only terminal symbol."
      end
      raise errors.join("\n") unless errors.empty?
    end

    def validate_rule_lhs_is_nterm!
      errors = [] of String
      rules.each do |rule|
        lhs = rule.lhs
        next unless lhs
        next if lhs.nterm?
        errors << "[BUG] LHS of #{rule.display_name} (line: #{rule.lineno}) is terminal symbol. It should be nonterminal symbol."
      end
      raise errors.join("\n") unless errors.empty?
    end

    def validate_duplicated_precedence!
      errors = [] of String
      seen = {} of String => Precedence
      precedences.each do |prec|
        s_value = prec.s_value
        if first = seen[s_value]?
          errors << "%#{prec.type} redeclaration for #{s_value} (line: #{prec.lineno}) previous declaration was %#{first.type} (line: #{first.lineno})"
        else
          seen[s_value] = prec
        end
      end
      raise errors.join("\n") unless errors.empty?
    end

    def set_locations
      @locations = @locations || @rules.any?(&.contains_at_reference?)
    end

    private def build_printers
      @printers.map do |decl|
        Printer.new(decl.targets, decl.code, decl.code.line)
      end
    end

    private def build_destructors
      @destructors.map do |decl|
        Destructor.new(decl.targets, decl.code, decl.code.line)
      end
    end

    private def build_error_tokens
      @error_tokens.map do |decl|
        ErrorToken.new(decl.targets, decl.code, decl.code.line)
      end
    end

    private def sort_precedence
      @precedences.sort_by! do |prec|
        prec.symbol.number || 0
      end
    end

    private def compute_nullable
      @rules.each do |rule|
        if rule.empty_rule?
          rule.nullable = true
        elsif rule.rhs.any?(&.term?)
          rule.nullable = false
        end
      end

      loop do
        rules_without_nullable = @rules.select { |rule| rule.nullable.nil? }
        nterms_without_nullable = nterms.select { |nterm| nterm.nullable.nil? }
        rule_count_1 = rules_without_nullable.size
        nterm_count_1 = nterms_without_nullable.size

        rules_without_nullable.each do |rule|
          rule.nullable = true if rule.rhs.all? { |sym| sym.nullable == true }
        end

        nterms_without_nullable.each do |nterm|
          find_rules_by_symbol!(nterm).each do |rule|
            nterm.nullable = true if rule.nullable == true
          end
        end

        rule_count_2 = @rules.count { |rule| rule.nullable.nil? }
        nterm_count_2 = nterms.count { |nterm| nterm.nullable.nil? }
        break if rule_count_1 == rule_count_2 && nterm_count_1 == nterm_count_2
      end

      rules.select { |rule| rule.nullable.nil? }.each(&.nullable=(false))
      nterms.select { |nterm| nterm.nullable.nil? }.each(&.nullable=(false))
    end

    private def compute_first_set
      terms.each do |term|
        term.first_set = Set{term}
        if number = term.number
          term.first_set_bitmap = Bitmap.from_array([number])
        else
          term.first_set_bitmap = Bitmap.from_array([] of Int32)
        end
      end

      nterms.each do |nterm|
        nterm.first_set = Set(Grammar::Symbol).new
        nterm.first_set_bitmap = Bitmap.from_array([] of Int32)
      end

      loop do
        changed = false
        @rules.each do |rule|
          lhs = rule.lhs
          next unless lhs
          rule.rhs.each do |sym|
            lhs_bitmap = lhs.first_set_bitmap || Bitmap.from_array([] of Int32)
            sym_bitmap = sym.first_set_bitmap || Bitmap.from_array([] of Int32)
            merged = lhs_bitmap | sym_bitmap
            if merged != lhs_bitmap
              changed = true
              lhs.first_set_bitmap = merged
            end
            break unless sym.nullable == true
          end
        end
        break unless changed
      end

      nterms.each do |nterm|
        nterm.first_set = Bitmap.to_array(nterm.first_set_bitmap || Bitmap.from_array([] of Int32)).map do |number|
          find_symbol_by_number!(number)
        end.to_set
      end
    end

    private def start_rule_token : Lexer::Token::Base
      if value = start_symbol
        return find_rule_lhs_by_s_value(value)
      end
      first_builder = @rule_builders.first?
      if first_builder && (lhs = first_builder.lhs)
        return lhs
      end
      Lexer::Token::Ident.new("$accept", location: internal_location)
    end

    private def find_rule_lhs_by_s_value(value : String) : Lexer::Token::Base
      if builder = @rule_builders.find { |rule_builder| rule_builder.lhs.try(&.s_value) == value }
        lhs = builder.lhs
        return lhs if lhs
      end
      Lexer::Token::Ident.new(value, location: internal_location)
    end

    private def internal_location
      if location = @internal_location
        return location
      end
      file = Lexer::GrammarFile.new("<internal>", "")
      location = Lexer::Location.new(
        grammar_file: file,
        first_line: 1,
        first_column: 0,
        last_line: 1,
        last_column: 0
      )
      @internal_location = location
      location
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
      getter kind : ::Symbol
      getter tag : Lexer::Token::Tag?
      getter tokens : Array(Lexer::Token::Base)

      def initialize(@kind : ::Symbol, @tag : Lexer::Token::Tag?, @tokens : Array(Lexer::Token::Base))
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
