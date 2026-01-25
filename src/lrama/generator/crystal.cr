require "ecr"

module Lrama
  module Generator
    class Crystal
      struct Tables
        getter yypact : Array(Int32)
        getter yypgoto : Array(Int32)
        getter yydefact : Array(Int32)
        getter yydefgoto : Array(Int32)
        getter yytable : Array(Int32)
        getter yycheck : Array(Int32)
        getter yyr1 : Array(Int32)
        getter yyr2 : Array(Int32)
        getter yylast : Int32
        getter yypact_ninf : Int32
        getter yytable_ninf : Int32
        getter yyfinal : Int32
        getter error_symbol : Int32
        getter eof_symbol : Int32
        getter yyntokens : Int32

        def initialize(
          @yypact : Array(Int32),
          @yypgoto : Array(Int32),
          @yydefact : Array(Int32),
          @yydefgoto : Array(Int32),
          @yytable : Array(Int32),
          @yycheck : Array(Int32),
          @yyr1 : Array(Int32),
          @yyr2 : Array(Int32),
          @yylast : Int32,
          @yypact_ninf : Int32,
          @yytable_ninf : Int32,
          @yyfinal : Int32,
          @error_symbol : Int32,
          @eof_symbol : Int32,
          @yyntokens : Int32,
        )
        end
      end

      def initialize(@grammar : Grammar, @tables : Tables, @class_name : String = "Parser")
      end

      def render(io : IO)
        ECR.embed "#{__DIR__}/templates/parser.ecr", io
      end

      private def reduce_case(rule : Grammar::Rule, rule_id : Int32)
        output = IO::Memory.new
        output.puts "    when #{rule_id}"
        output.puts "      # #{rule.display_name}"
        if code = rule.token_code
          if needs_lhs_location?(code)
            output.puts "      location = reduce_location(rule, locations)"
          end
          output.puts "      result = #{default_result(rule)}"
          translated = translate_action(rule, code)
          translated.each_line do |line|
            line = line.rstrip
            if line.empty?
              output.puts
            else
              output.puts "      #{line}"
            end
          end
          output.puts "      result"
        else
          output.puts "      #{default_result(rule)}"
        end
        output.to_s
      end

      private def needs_lhs_location?(code : Lexer::Token::UserCode)
        code.references.any? { |ref| ref.type == :at && ref.name == "$" }
      end

      private def default_result(rule : Grammar::Rule)
        rule.rhs.empty? ? "nil" : "values.last?"
      end

      private def translate_action(rule : Grammar::Rule, code : Lexer::Token::UserCode)
        translated = code.s_value.dup
        code.references.reverse_each do |ref|
          translated = replace_reference(translated, rule, ref)
        end
        translated
      end

      private def replace_reference(code : String, rule : Grammar::Rule, ref : Grammar::Reference)
        start = ref.first_column
        finish = ref.last_column
        replacement = reference_to_crystal(rule, ref)
        head = start > 0 ? (code.byte_slice(0, start) || "") : ""
        tail_len = code.bytesize - finish
        tail = tail_len > 0 ? (code.byte_slice(finish, tail_len) || "") : ""
        "#{head}#{replacement}#{tail}"
      end

      # ameba:disable Metrics/CyclomaticComplexity
      private def reference_to_crystal(rule : Grammar::Rule, ref : Grammar::Reference)
        case
        when ref.type == :dollar && ref.name == "$"
          "result"
        when ref.type == :at && ref.name == "$"
          "location"
        when ref.type == :index && ref.name == "$"
          raise "$:$ is not supported"
        when ref.type == :dollar
          index = ref.index || raise "Reference index missing. #{ref}"
          "values[#{index - 1}]"
        when ref.type == :at
          index = ref.index || raise "Reference index missing. #{ref}"
          "locations[#{index - 1}]"
        when ref.type == :index
          index = ref.index || raise "Reference index missing. #{ref}"
          position_in_rhs = rule.position_in_original_rule_rhs || rule.rhs.size
          (index - position_in_rhs - 1).to_s
        else
          raise "Unexpected. #{self}, #{ref}"
        end
      end

      # ameba:enable Metrics/CyclomaticComplexity

      private def format_array(values : Array(Int32))
        return "[] of Int32" if values.empty?
        chunks = values.each_slice(12).map(&.join(", ")).to_a
        if chunks.size == 1
          "[#{chunks.first}]"
        else
          "[\n    #{chunks.join(",\n    ")}\n  ]"
        end
      end
    end
  end
end
