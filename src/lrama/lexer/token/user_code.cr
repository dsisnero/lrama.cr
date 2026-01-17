module Lrama
  class Lexer
    module Token
      class UserCode < Base
        property tag : Tag?

        @references : Array(Grammar::Reference)?

        def references
          @references ||= build_references
        end

        def code
          s_value
        end

        private def build_references
          scanner = StringScanner.new(s_value)
          references = [] of Grammar::Reference

          until scanner.eos?
            if reference = scan_reference(scanner)
              references << reference
              next
            end

            if scanner.scan(/\/\*/)
              scanner.scan_until(/\*\//)
              next
            end

            scanner.scan(/./m)
          end

          references
        end

        private def scan_reference(scanner : StringScanner)
          start = scanner.offset
          return unless scanner.scan(/
            # $ references
            \$(<[a-zA-Z0-9_]+>)?(?:
              (\$)                            # $$, $<long>$
            | (\d+)                           # $1, $2, $<long>1
            | ([a-zA-Z_][a-zA-Z0-9_]*)        # $foo, $expr, $<long>program
            | \[([a-zA-Z_.][-a-zA-Z0-9_.]*)\] # $[expr.right], $[expr-right]
            )
          |
            # @ references
            @(?:
              (\$)                            # @$
            | (\d+)                           # @1
            | ([a-zA-Z_][a-zA-Z0-9_]*)        # @foo, @expr
            | \[([a-zA-Z_.][-a-zA-Z0-9_.]*)\] # @[expr.right], @[expr-right]
            )
          |
            # $: references
            \$:
            (?:
              (\$)                            # $:$
            | (\d+)                           # $:1
            | ([a-zA-Z_][a-zA-Z0-9_]*)        # $:foo, $:expr
            | \[([a-zA-Z_.][-a-zA-Z0-9_.]*)\] # $:[expr.right], $:[expr-right]
            )
          /x)

          build_dollar_reference(scanner, start) ||
            build_at_reference(scanner, start) ||
            build_index_reference(scanner, start)
        end

        private def build_tag(raw_tag : String?)
          return unless raw_tag
          tag_location = location
          Lexer::Token::Tag.new(raw_tag, tag_location)
        end

        private def build_dollar_reference(scanner : StringScanner, start : Int32)
          tag = build_tag(scanner[1]?)
          if scanner[2]? # $$, $<long>$
            return Grammar::Reference.new(
              type: :dollar,
              name: "$",
              ex_tag: tag,
              first_column: start,
              last_column: scanner.offset
            )
          end

          if value = scanner[3]? # $1, $2, $<long>1
            number = value.to_i
            return Grammar::Reference.new(
              type: :dollar,
              number: number,
              index: number,
              ex_tag: tag,
              first_column: start,
              last_column: scanner.offset
            )
          end

          if value = scanner[4]? # $foo, $expr, $<long>program
            return Grammar::Reference.new(
              type: :dollar,
              name: value,
              ex_tag: tag,
              first_column: start,
              last_column: scanner.offset
            )
          end

          if value = scanner[5]? # $[expr.right], $[expr-right], $<long>[expr.right]
            return Grammar::Reference.new(
              type: :dollar,
              name: value,
              ex_tag: tag,
              first_column: start,
              last_column: scanner.offset
            )
          end
        end

        private def build_at_reference(scanner : StringScanner, start : Int32)
          if scanner[6]? # @$
            return Grammar::Reference.new(
              type: :at,
              name: "$",
              first_column: start,
              last_column: scanner.offset
            )
          end

          if value = scanner[7]? # @1
            number = value.to_i
            return Grammar::Reference.new(
              type: :at,
              number: number,
              index: number,
              first_column: start,
              last_column: scanner.offset
            )
          end

          if value = scanner[8]? # @foo, @expr
            return Grammar::Reference.new(
              type: :at,
              name: value,
              first_column: start,
              last_column: scanner.offset
            )
          end

          if value = scanner[9]? # @[expr.right], @[expr-right]
            return Grammar::Reference.new(
              type: :at,
              name: value,
              first_column: start,
              last_column: scanner.offset
            )
          end
        end

        private def build_index_reference(scanner : StringScanner, start : Int32)
          if scanner[10]? # $:$
            return Grammar::Reference.new(
              type: :index,
              name: "$",
              first_column: start,
              last_column: scanner.offset
            )
          end

          if value = scanner[11]? # $:1
            number = value.to_i
            return Grammar::Reference.new(
              type: :index,
              number: number,
              index: number,
              first_column: start,
              last_column: scanner.offset
            )
          end

          if value = scanner[12]? # $:foo, $:expr
            return Grammar::Reference.new(
              type: :index,
              name: value,
              first_column: start,
              last_column: scanner.offset
            )
          end

          if value = scanner[13]? # $:[expr.right], $:[expr-right]
            return Grammar::Reference.new(
              type: :index,
              name: value,
              first_column: start,
              last_column: scanner.offset
            )
          end
        end
      end
    end
  end
end
