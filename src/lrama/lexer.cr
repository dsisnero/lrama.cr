require "string_scanner"

require "./lexer/grammar_file"
require "./lexer/location"
require "./lexer/token"
require "./parse_error"

module Lrama
  class Lexer
    alias LexerToken = Tuple(String, Token::Token) |
                       Tuple(Symbol, Token::Tag) |
                       Tuple(Symbol, Token::Char) |
                       Tuple(Symbol, Token::Str) |
                       Tuple(Symbol, Token::Int) |
                       Tuple(Symbol, Token::Ident)
    alias CToken = Tuple(Symbol, Token::UserCode)
    alias TokenValue = LexerToken | CToken

    getter head_line : Int32
    getter head_column : Int32
    getter line : Int32
    property status : Symbol
    property end_symbol : String?

    SYMBOLS        = ["%{", "%}", "%%", "{", "}", "[", "]", "(", ")", ",", ":", "|", ";"]
    PERCENT_TOKENS = [
      "%union",
      "%token",
      "%type",
      "%nterm",
      "%left",
      "%right",
      "%nonassoc",
      "%expect",
      "%define",
      "%require",
      "%printer",
      "%destructor",
      "%lex-param",
      "%parse-param",
      "%initial-action",
      "%precedence",
      "%prec",
      "%error-token",
      "%before-reduce",
      "%after-reduce",
      "%after-shift-error-token",
      "%after-shift",
      "%after-pop-stack",
      "%empty",
      "%code",
      "%rule",
      "%no-stdlib",
      "%inline",
      "%locations",
      "%categories",
      "%start",
    ]

    @grammar_file : GrammarFile
    @scanner : StringScanner
    @head : Int32

    def initialize(@grammar_file : GrammarFile)
      @scanner = StringScanner.new(grammar_file.text)
      @head_column = @head = @scanner.offset
      @head_line = @line = 1
      @status = :initial
      @end_symbol = nil
    end

    def next_token : TokenValue?
      case status
      when :initial
        lex_token
      when :c_declaration
        lex_c_code
      end
    end

    def column
      @scanner.offset - @head
    end

    def location
      Location.new(
        grammar_file: @grammar_file,
        first_line: head_line,
        first_column: head_column,
        last_line: line,
        last_column: column
      )
    end

    def lex_token : LexerToken?
      consume_whitespace_and_comments
      reset_first_position

      return if @scanner.eos?

      scan_symbol ||
        scan_percent ||
        scan_operator ||
        scan_tag ||
        scan_character ||
        scan_string ||
        scan_integer ||
        scan_identifier ||
        raise ParseError.new(location.generate_error_message("Unexpected token"))
    end

    def lex_c_code : CToken
      nested = 0
      end_sym = end_symbol
      reset_first_position
      io = String::Builder.new

      until @scanner.eos?
        if end_sym == "}" && nested == 0 && @scanner.check(/}/)
          return {:C_DECLARATION, Token::UserCode.new(io.to_s, location: location)}
        end
        if end_sym && @scanner.check(/#{Regex.escape(end_sym)}/)
          return {:C_DECLARATION, Token::UserCode.new(io.to_s, location: location)}
        end
        nested = scan_c_code_chunk(io, end_sym, nested)
      end

      code = io.to_s

      if end_sym == "\\Z"
        return {:C_DECLARATION, Token::UserCode.new(code, location: location)}
      end

      raise ParseError.new(location.generate_error_message("Unexpected code: #{code}"))
    end

    private def lex_comment
      until @scanner.eos?
        case
        when (matched = @scanner.scan_until(/[\s\S]*?\*\//))
          matched.count('\n').times { newline }
          return
        when @scanner.scan_until(/\n/)
          newline
        end
      end
    end

    private def consume_whitespace_and_comments
      until @scanner.eos?
        case
        when @scanner.scan(/\n/)
          newline
        when (matched = @scanner.scan(/\s+/))
          matched.count('\n').times { newline }
        when @scanner.scan(/\/\*/)
          lex_comment
        when @scanner.scan(/\/\/.*\n/)
          newline
        when @scanner.scan(/\/\/.*/)
          break
        else
          break
        end
      end
    end

    private def scan_symbol
      matched = @scanner.scan(symbol_pattern)
      return unless matched
      {matched, Token::Token.new(matched, location: location)}
    end

    private def scan_percent
      matched = @scanner.scan(percent_pattern)
      return unless matched
      {matched, Token::Token.new(matched, location: location)}
    end

    private def scan_operator
      matched = @scanner.scan(/[\?\+\*]/)
      return unless matched
      {matched, Token::Token.new(matched, location: location)}
    end

    private def scan_tag
      matched = @scanner.scan(/<\w+>/)
      return unless matched
      {:TAG, Token::Tag.new(matched, location: location)}
    end

    private def scan_character
      matched = @scanner.scan(/'.'/) || @scanner.scan(/'\\\\'|'\\b'|'\\t'|'\\f'|'\\r'|'\\n'|'\\v'|'\\13'/)
      return {:CHARACTER, Token::Char.new(matched, location: location)} if matched
    end

    private def scan_string
      matched = @scanner.scan(/".*?"/)
      return unless matched
      {:STRING, Token::Str.new(matched, location: location)}
    end

    private def scan_integer
      matched = @scanner.scan(/\d+/)
      return unless matched
      {:INTEGER, Token::Int.new(matched, location: location)}
    end

    private def scan_identifier
      matched = @scanner.scan(/([a-zA-Z_.][-a-zA-Z0-9_.]*)/)
      return unless matched
      token = Token::Ident.new(matched, location: location)
      type = if @scanner.check(/\s*(\[\s*[a-zA-Z_.][-a-zA-Z0-9_.]*\s*\])?\s*:/)
               :IDENT_COLON
             else
               :IDENTIFIER
             end
      {type, token}
    end

    private def reset_first_position
      @head_line = line
      @head_column = column
    end

    private def newline
      @line += 1
      @head = @scanner.offset
    end

    private def symbol_pattern
      @symbol_pattern ||= Regex.new(SYMBOLS.map { |symbol| Regex.escape(symbol) }.join("|"))
    end

    private def percent_pattern
      @percent_pattern ||= Regex.new(PERCENT_TOKENS.map { |token| Regex.escape(token) }.join("|"))
    end

    private def scan_c_code_chunk(io : String::Builder, end_sym : String?, nested : Int32)
      if matched = @scanner.scan(/{/)
        io << matched
        return nested + 1
      end
      if matched = @scanner.scan(/}/)
        io << matched
        return nested - 1
      end
      if matched = @scanner.scan(/\n/)
        io << matched
        newline
        return nested
      end
      if matched = @scanner.scan(/".*?"/)
        io << matched
        @line += matched.count('\n')
        return nested
      end
      if matched = @scanner.scan(/'.*?'/)
        io << matched
        return nested
      end
      if matched = @scanner.scan(/[^\"'\{\}\n]+/)
        io << matched
        return nested
      end
      if end_sym && (matched = @scanner.scan(/#{Regex.escape(end_sym)}/))
        io << matched
        return nested
      end
      if matched = @scanner.scan(/./m)
        io << matched
      end
      nested
    end
  end
end
