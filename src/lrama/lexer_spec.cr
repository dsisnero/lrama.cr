require "string_scanner"

module Lrama
  class LexerSpec
    class ParseError < Exception
    end

    enum ValueKind
      None
      Int
      Float
      String
      Symbol
    end

    struct Rule
      getter kind : Symbol
      getter name : String?
      getter pattern : RegexAst
      getter value_kind : ValueKind
      getter? keyword
      getter states : Array(String)
      getter line : Int32

      def initialize(
        @kind : Symbol,
        @name : String?,
        @pattern : RegexAst,
        @value_kind : ValueKind,
        @keyword : Bool,
        @states : Array(String),
        @line : Int32,
      )
      end

      def token?
        kind == :token
      end

      def skip?
        kind == :skip
      end
    end

    abstract class RegexAst
    end

    class Sequence < RegexAst
      getter parts : Array(RegexAst)

      def initialize(@parts : Array(RegexAst))
      end
    end

    class Literal < RegexAst
      getter byte : UInt8

      def initialize(@byte : UInt8)
      end
    end

    class CharClass < RegexAst
      getter set : ByteSet

      def initialize(@set : ByteSet)
      end
    end

    class AnyChar < RegexAst
    end

    class Alternation < RegexAst
      getter options : Array(RegexAst)

      def initialize(@options : Array(RegexAst))
      end
    end

    class Repeat < RegexAst
      getter node : RegexAst
      getter min : Int32
      getter max : Int32?

      def initialize(@node : RegexAst, @min : Int32, @max : Int32?)
      end
    end

    struct ByteSet
      getter bits : StaticArray(UInt64, 4)

      def initialize
        @bits = StaticArray(UInt64, 4).new(0_u64)
      end

      def initialize(@bits : StaticArray(UInt64, 4))
      end

      def add(byte : UInt8)
        index = byte // 64
        offset = byte % 64
        @bits = @bits.dup
        @bits[index] |= (1_u64 << offset)
      end

      def add_range(start_byte : UInt8, end_byte : UInt8)
        value = start_byte.to_i
        last = end_byte.to_i
        while value <= last
          add(value.to_u8)
          value += 1
        end
      end

      def include?(byte : UInt8)
        index = byte // 64
        offset = byte % 64
        ((@bits[index] >> offset) & 1_u64) == 1_u64
      end

      def invert : ByteSet
        inverted = StaticArray(UInt64, 4).new(UInt64::MAX)
        ByteSet.new(StaticArray[
          @bits[0] ^ inverted[0],
          @bits[1] ^ inverted[1],
          @bits[2] ^ inverted[2],
          @bits[3] ^ inverted[3],
        ])
      end

      def self.full : ByteSet
        ByteSet.new(StaticArray(UInt64, 4).new(UInt64::MAX))
      end
    end

    getter rules : Array(Rule)
    getter keywords : Array(String)
    getter? keywords_case_insensitive
    getter states : Array(String)

    def initialize(
      @rules : Array(Rule),
      @keywords : Array(String),
      @keywords_case_insensitive : Bool,
      @states : Array(String),
    )
    end

    class Parser
      def initialize(@source : String, @start_line : Int32)
      end

      def parse : LexerSpec
        rules = [] of Rule
        keywords = [] of String
        keywords_case_insensitive = false
        states = ["INITIAL"]
        @source.each_line.with_index do |raw_line, offset|
          line = raw_line.strip
          next if line.empty?
          next if line.starts_with?("#")
          if line.starts_with?("keywords")
            parsed_keywords, parsed_case_insensitive = parse_keywords(line, @start_line + offset)
            keywords.concat(parsed_keywords)
            keywords_case_insensitive ||= parsed_case_insensitive
          elsif line.starts_with?("state ")
            state_name = parse_state(line, @start_line + offset)
            states << state_name unless states.includes?(state_name)
          else
            rule = parse_rule(line, @start_line + offset, states)
            rules << rule
          end
        end
        if rules.any?(&.keyword?) && keywords.empty?
          raise ParseError.new("Keyword rules require a keywords directive")
        end
        LexerSpec.new(rules, keywords, keywords_case_insensitive, states)
      end

      private def parse_rule(line : String, line_number : Int32, states : Array(String))
        parts = line.split(/\s+/, 3)
        kind = parts[0]? || raise ParseError.new("Expected rule at line #{line_number}")
        if kind == "skip"
          pattern_text = parts[1]? || raise ParseError.new("Expected pattern at line #{line_number}")
          pattern_text, _, _, states_override = split_pattern_and_kind(pattern_text, line_number, parts[2]?)
          pattern = parse_pattern(pattern_text, line_number)
          rule_states = resolve_rule_states(states, states_override, line_number)
          return Rule.new(:skip, nil, pattern, ValueKind::None, false, rule_states, line_number)
        end

        unless kind == "token"
          raise ParseError.new("Unknown lexer directive '#{kind}' at line #{line_number}")
        end

        name = parts[1]? || raise ParseError.new("Expected token name at line #{line_number}")
        rest = parts[2]? || raise ParseError.new("Expected pattern at line #{line_number}")
        pattern_text, value_kind, keyword, states_override = split_pattern_and_kind(rest, line_number, nil)
        pattern = parse_pattern(pattern_text, line_number)
        rule_states = resolve_rule_states(states, states_override, line_number)
        Rule.new(:token, name, pattern, value_kind, keyword, rule_states, line_number)
      end

      private def split_pattern_and_kind(rest : String, line_number : Int32, options_text : String?)
        scanner = StringScanner.new(rest)
        pattern_text = parse_pattern_text(scanner, line_number)
        option_source = options_text
        option_source = scanner.rest.strip if option_source.nil?
        options = option_source.to_s.strip
        value_kind = ValueKind::None
        keyword = false
        states_override = nil.as(Array(String)?)
        unless options.empty?
          options.split(/\s+/).each do |option|
            if option == "keyword"
              keyword = true
            elsif option.starts_with?("in=") || option.starts_with?("in:")
              list = option.split(/[=:]/, 2)[1]? || ""
              states_override = list.split(",").reject(&.empty?)
            else
              value_kind = parse_value_kind(option, line_number)
            end
          end
        end
        {pattern_text, value_kind, keyword, states_override}
      end

      private def resolve_rule_states(states : Array(String), override : Array(String)?, line_number : Int32)
        rule_states = override || ["INITIAL"]
        rule_states.each do |name|
          unless states.includes?(name)
            raise ParseError.new("Unknown lexer state '#{name}' at line #{line_number}")
          end
        end
        rule_states
      end

      private def parse_keywords(line : String, line_number : Int32)
        parts = line.split(/\s+/)
        raise ParseError.new("Expected keyword list at line #{line_number}") if parts.size < 2
        case_insensitive = false
        index = 1
        if parts[index]? == "case_insensitive"
          case_insensitive = true
          index += 1
        end
        keywords = parts[index..-1]? || [] of String
        if keywords.empty?
          raise ParseError.new("Expected keyword list at line #{line_number}")
        end
        {keywords, case_insensitive}
      end

      private def parse_state(line : String, line_number : Int32)
        parts = line.split(/\s+/, 2)
        raise ParseError.new("Expected state name at line #{line_number}") unless parts[1]?
        parts[1]
      end

      private def parse_value_kind(text : String, line_number : Int32)
        case text
        when "int"
          ValueKind::Int
        when "float"
          ValueKind::Float
        when "string"
          ValueKind::String
        when "symbol"
          ValueKind::Symbol
        when ""
          ValueKind::None
        else
          raise ParseError.new("Unknown value kind '#{text}' at line #{line_number}")
        end
      end

      private def parse_pattern_text(scanner : StringScanner, line_number : Int32)
        scanner.skip(/\s+/)
        if scanner.scan(/\//)
          pattern = scanner.scan_until(/(?<!\\)\//)
          raise ParseError.new("Unterminated pattern at line #{line_number}") unless pattern
          pattern[0...-1]
        elsif scanner.scan(/"/)
          pattern = scanner.scan_until(/(?<!\\)"/)
          raise ParseError.new("Unterminated string at line #{line_number}") unless pattern
          "\"#{pattern[0...-1]}\""
        else
          raise ParseError.new("Expected pattern at line #{line_number}")
        end
      end

      private def parse_pattern(pattern_text : String, line_number : Int32)
        if pattern_text.starts_with?("\"") && pattern_text.ends_with?("\"")
          content = unescape_string(pattern_text[1...-1])
          parts = content.bytes.map { |byte| Literal.new(byte).as(RegexAst) }
          return Sequence.new(parts)
        end

        RegexParser.new(pattern_text, line_number).parse
      end

      private def unescape_string(text : String)
        text.gsub(/\\n/, "\n")
          .gsub(/\\t/, "\t")
          .gsub(/\\r/, "\r")
          .gsub(/\\f/, "\f")
          .gsub(/\\v/, "\v")
          .gsub(/\\\\/, "\\")
          .gsub(/\\"/, "\"")
      end
    end

    class RegexParser
      def initialize(@pattern : String, @line_number : Int32)
        @scanner = StringScanner.new(pattern)
      end

      def parse : RegexAst
        parse_expression(nil)
      end

      private def parse_expression(terminator : Char?)
        alternatives = [] of RegexAst
        loop do
          alternatives << parse_sequence(terminator)
          break unless @scanner.scan(/\|/)
        end
        return alternatives.first if alternatives.size == 1
        Alternation.new(alternatives)
      end

      private def parse_sequence(terminator : Char?)
        parts = [] of RegexAst
        while !@scanner.eos?
          char = peek_char
          break if char == '|' || (terminator && char == terminator)
          parts << parse_atom
        end
        Sequence.new(parts)
      end

      private def parse_atom
        node = parse_primary

        parse_quantifier(node)
      end

      private def parse_quantifier(node : RegexAst)
        if quantifier = @scanner.scan(/[\*\+\?]/)
          return Repeat.new(node, 0, nil) if quantifier == "*"
          return Repeat.new(node, 1, nil) if quantifier == "+"
          return Repeat.new(node, 0, 1)
        end

        return node unless @scanner.scan(/\{/)
        min_text = @scanner.scan(/\d+/)
        raise ParseError.new("Expected repetition lower bound at line #{@line_number}") unless min_text
        min = min_text.to_i
        max = min
        if @scanner.scan(/,/)
          if max_text = @scanner.scan(/\d+/)
            max = max_text.to_i
          else
            max = nil
          end
        end
        raise ParseError.new("Expected closing '}' at line #{@line_number}") unless @scanner.scan(/\}/)
        if max && max < min
          raise ParseError.new("Invalid repetition range at line #{@line_number}")
        end
        Repeat.new(node, min, max)
      end

      private def parse_primary
        if @scanner.scan(/\[/)
          parse_char_class
        elsif @scanner.scan(/\(/)
          node = parse_expression(')')
          raise ParseError.new("Unterminated group at line #{@line_number}") unless @scanner.scan(/\)/)
          node
        elsif @scanner.scan(/\./)
          AnyChar.new
        else
          parse_literal
        end
      end

      private def parse_char_class
        set = ByteSet.new
        negated = false
        first = true
        if peek_char == '^'
          next_char
          negated = true
        end
        prev = nil.as(UInt8?)
        while char = next_char
          break if char == ']' && !first
          first = false
          if char == '\\'
            set, prev = add_escaped_char_class_byte(set)
            next
          end
          if char == '-' && prev
            next_char_value = next_char
            if next_char_value.nil?
              set.add('-'.ord.to_u8)
              break
            end
            range = parse_range_end(next_char_value)
            if range[:end_of_class]
              set.add('-'.ord.to_u8)
              break
            end
            set.add_range(prev, range[:value])
            prev = range[:value]
            next
          end
          set, prev = add_literal_char_class_byte(set, char)
        end
        set = set.invert if negated
        CharClass.new(set)
      end

      private def add_escaped_char_class_byte(set : ByteSet)
        escaped = next_char
        raise ParseError.new("Unterminated escape at line #{@line_number}") unless escaped
        byte = escape_char(escaped)
        set.add(byte)
        {set, byte}
      end

      private def add_literal_char_class_byte(set : ByteSet, char : Char)
        byte = char.ord.to_u8
        set.add(byte)
        {set, byte}
      end

      private def parse_range_end(char : Char)
        if char == ']'
          {end_of_class: true, value: 0_u8}
        elsif char == '\\'
          escaped = next_char
          raise ParseError.new("Unterminated escape at line #{@line_number}") unless escaped
          {end_of_class: false, value: escape_char(escaped)}
        else
          {end_of_class: false, value: char.ord.to_u8}
        end
      end

      private def parse_literal
        char = next_char
        raise ParseError.new("Unexpected end of pattern at line #{@line_number}") unless char
        if char == '\\'
          escaped = next_char
          raise ParseError.new("Unterminated escape at line #{@line_number}") unless escaped
          return Literal.new(escape_char(escaped))
        end
        if char == '|' || char == ')'
          raise ParseError.new("Unexpected '#{char}' at line #{@line_number}")
        end
        Literal.new(char.ord.to_u8)
      end

      private def next_char
        token = @scanner.scan(/./)
        token ? token[0] : nil
      end

      private def peek_char
        token = @scanner.peek(1)
        token.empty? ? nil : token[0]
      end

      private def escape_char(char : Char)
        case char
        when 'n'
          '\n'.ord.to_u8
        when 't'
          '\t'.ord.to_u8
        when 'r'
          '\r'.ord.to_u8
        when 'f'
          '\f'.ord.to_u8
        when 'v'
          '\v'.ord.to_u8
        else
          char.ord.to_u8
        end
      end
    end
  end
end
