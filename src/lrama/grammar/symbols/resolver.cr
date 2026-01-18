require "set"

module Lrama
  class Grammar
    module Symbols
      class Resolver
        getter terms : Array(Grammar::Symbol)
        getter nterms : Array(Grammar::Symbol)
        @symbols : Array(Grammar::Symbol)?
        @number : Int32
        @used_numbers : Hash(Int32, Bool)

        def initialize
          @terms = [] of Grammar::Symbol
          @nterms = [] of Grammar::Symbol
          @symbols = nil
          @number = 0
          @used_numbers = {} of Int32 => Bool
        end

        def symbols
          @symbols ||= terms + nterms
        end

        def sort_by_number!
          symbols.sort_by! { |sym| sym.number || 0 }
        end

        def add_term(
          id : Lexer::Token::Base,
          alias_name : String? = nil,
          tag : Lexer::Token::Tag? = nil,
          token_id : Int32? = nil,
          replace : Bool = false,
        )
          if token_id && (sym = find_symbol_by_token_id(token_id))
            if replace
              sym.id = id
              sym.alias_name = alias_name
              sym.tag = tag
            end
            return sym
          end

          if sym = find_symbol_by_id(id)
            return sym
          end

          @symbols = nil
          term = Grammar::Symbol.new(
            id: id,
            alias_name: alias_name,
            number: nil,
            tag: tag,
            term: true,
            token_id: token_id,
            nullable: false
          )
          @terms << term
          term
        end

        def add_nterm(id : Lexer::Token::Base, alias_name : String? = nil, tag : Lexer::Token::Tag? = nil)
          if sym = find_symbol_by_id(id)
            return sym
          end

          @symbols = nil
          nterm = Grammar::Symbol.new(
            id: id,
            alias_name: alias_name,
            number: nil,
            tag: tag,
            term: false,
            token_id: nil,
            nullable: nil
          )
          @nterms << nterm
          nterm
        end

        def find_term_by_s_value(s_value : String)
          terms.find { |sym| sym.id.s_value == s_value }
        end

        def find_symbol_by_s_value(s_value : String)
          symbols.find { |sym| sym.id.s_value == s_value }
        end

        def find_symbol_by_s_value!(s_value : String)
          find_symbol_by_s_value(s_value) || raise "Symbol not found. value: `#{s_value}`"
        end

        def find_symbol_by_id(id : Lexer::Token::Base)
          symbols.find do |sym|
            sym.id == id || sym.alias_name == id.s_value
          end
        end

        def find_symbol_by_id!(id : Lexer::Token::Base)
          find_symbol_by_id(id) || raise "Symbol not found. #{id}"
        end

        def find_symbol_by_token_id(token_id : Int32)
          symbols.find { |sym| sym.token_id == token_id }
        end

        def find_symbol_by_number!(number : Int32)
          sym = symbols[number]?
          raise "Symbol not found. number: `#{number}`" unless sym
          raise "[BUG] Symbol number mismatch. #{number}, #{sym}" if sym.number != number
          sym
        end

        def fill_symbol_number
          @number = 3
          fill_terms_number
          fill_nterms_number
        end

        def fill_nterm_type(types : Array(Grammar::Type))
          types.each do |type|
            nterm = find_nterm_by_id!(type.id)
            nterm.tag = type.tag
          end
        end

        def fill_printer(printers : Array(Grammar::Printer))
          symbols.each do |sym|
            printers.each do |printer|
              printer.ident_or_tags.each do |ident_or_tag|
                case ident_or_tag
                when Lexer::Token::Ident
                  sym.printer = printer if sym.id == ident_or_tag
                when Lexer::Token::Tag
                  sym.printer = printer if sym.tag == ident_or_tag
                else
                  raise "Unknown token type. #{printer}"
                end
              end
            end
          end
        end

        def fill_destructor(destructors : Array(Grammar::Destructor))
          symbols.each do |sym|
            destructors.each do |destructor|
              destructor.ident_or_tags.each do |ident_or_tag|
                case ident_or_tag
                when Lexer::Token::Ident
                  sym.destructor = destructor if sym.id == ident_or_tag
                when Lexer::Token::Tag
                  sym.destructor = destructor if sym.tag == ident_or_tag
                else
                  raise "Unknown token type. #{destructor}"
                end
              end
            end
          end
        end

        def fill_error_token(error_tokens : Array(Grammar::ErrorToken))
          symbols.each do |sym|
            error_tokens.each do |token|
              token.ident_or_tags.each do |ident_or_tag|
                case ident_or_tag
                when Lexer::Token::Ident
                  sym.error_token = token if sym.id == ident_or_tag
                when Lexer::Token::Tag
                  sym.error_token = token if sym.tag == ident_or_tag
                else
                  raise "Unknown token type. #{token}"
                end
              end
            end
          end
        end

        def token_to_symbol(token : Lexer::Token::Base)
          find_symbol_by_id!(token)
        end

        def validate!
          validate_number_uniqueness!
          validate_alias_name_uniqueness!
          validate_symbols!
        end

        private def find_nterm_by_id!(id : Lexer::Token::Base)
          @nterms.find { |sym| sym.id == id } || raise "Symbol not found. #{id}"
        end

        private def fill_terms_number
          token_id = 256

          @terms.each do |sym|
            while used_numbers[@number]?
              @number += 1
            end

            if sym.number.nil?
              sym.number = @number
              used_numbers[@number] = true
              @number += 1
            end

            next unless sym.token_id.nil?

            if sym.id.is_a?(Lexer::Token::Char)
              sym.token_id = token_id_from_char(sym)
            else
              sym.token_id = token_id
              token_id += 1
            end
          end
        end

        private def token_id_from_char(sym : Grammar::Symbol)
          value = sym.id.s_value[1..-2]
          escape_map = {
            "\\b"  => 8,
            "\\f"  => 12,
            "\\n"  => 10,
            "\\r"  => 13,
            "\\t"  => 9,
            "\\v"  => 11,
            "\""   => 34,
            "'"    => 39,
            "\\\\" => 92,
          }
          if escaped = escape_map[value]?
            return escaped
          end

          if match = value.match(/\A\\(\d+)\z/)
            return match[1].to_i(8)
          end

          return value.bytes.first.to_i if value.size == 1
          raise "Unknown Char s_value #{sym}"
        end

        private def fill_nterms_number
          token_id = 0

          @nterms.each do |sym|
            while used_numbers[@number]?
              @number += 1
            end

            if sym.number.nil?
              sym.number = @number
              used_numbers[@number] = true
              @number += 1
            end

            if sym.token_id.nil?
              sym.token_id = token_id
              token_id += 1
            end
          end
        end

        private def used_numbers
          return @used_numbers unless @used_numbers.empty?

          symbols.compact_map(&.number).each do |number|
            @used_numbers[number] = true
          end
          @used_numbers
        end

        private def validate_number_uniqueness!
          invalid = symbols.group_by(&.number).select { |_, syms| syms.size > 1 }
          return if invalid.empty?
          raise "Symbol number is duplicated. #{invalid}"
        end

        private def validate_alias_name_uniqueness!
          invalid = symbols.select(&.alias_name).group_by(&.alias_name).select { |_, syms| syms.size > 1 }
          return if invalid.empty?
          raise "Symbol alias name is duplicated. #{invalid}"
        end

        private def validate_symbols!
          symbols.each(&.id.validate)
          errors = symbols.flat_map(&.id.errors)
          return if errors.empty?
          raise errors.join("\n")
        end
      end
    end
  end
end
