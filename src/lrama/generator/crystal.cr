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
        io.puts "class #{@class_name} < Lrama::Runtime::Parser"
        emit_symbols(io)
        emit_table_constants(io)
        emit_table_methods(io)
        emit_reduce_method(io)
        io.puts "end"
      end

      private def emit_symbols(io : IO)
        @grammar.symbols.sort_by { |sym| sym.number || 0 }.each do |sym|
          number = sym.number || 0
          io.puts "  #{sym.enum_name} = #{number}"
        end
        io.puts "  YYEMPTY = -2"
        io.puts "  YYERROR = #{@tables.error_symbol}"
        io.puts "  YYEOF = #{@tables.eof_symbol}"
        io.puts "  YYNTOKENS = #{@tables.yyntokens}"
        io.puts
      end

      private def emit_table_constants(io : IO)
        io.puts "  YYPACT = #{format_array(@tables.yypact)}"
        io.puts "  YYPGOTO = #{format_array(@tables.yypgoto)}"
        io.puts "  YYDEFACT = #{format_array(@tables.yydefact)}"
        io.puts "  YYDEFGOTO = #{format_array(@tables.yydefgoto)}"
        io.puts "  YYTABLE = #{format_array(@tables.yytable)}"
        io.puts "  YYCHECK = #{format_array(@tables.yycheck)}"
        io.puts "  YYR1 = #{format_array(@tables.yyr1)}"
        io.puts "  YYR2 = #{format_array(@tables.yyr2)}"
        io.puts "  YYLAST = #{@tables.yylast}"
        io.puts "  YYPACT_NINF = #{@tables.yypact_ninf}"
        io.puts "  YYTABLE_NINF = #{@tables.yytable_ninf}"
        io.puts "  YYFINAL = #{@tables.yyfinal}"
        io.puts
      end

      private def emit_table_methods(io : IO)
        io.puts "  def yypact : Array(Int32)"
        io.puts "    YYPACT"
        io.puts "  end"
        io.puts
        io.puts "  def yypgoto : Array(Int32)"
        io.puts "    YYPGOTO"
        io.puts "  end"
        io.puts
        io.puts "  def yydefact : Array(Int32)"
        io.puts "    YYDEFACT"
        io.puts "  end"
        io.puts
        io.puts "  def yydefgoto : Array(Int32)"
        io.puts "    YYDEFGOTO"
        io.puts "  end"
        io.puts
        io.puts "  def yytable : Array(Int32)"
        io.puts "    YYTABLE"
        io.puts "  end"
        io.puts
        io.puts "  def yycheck : Array(Int32)"
        io.puts "    YYCHECK"
        io.puts "  end"
        io.puts
        io.puts "  def yyr1 : Array(Int32)"
        io.puts "    YYR1"
        io.puts "  end"
        io.puts
        io.puts "  def yyr2 : Array(Int32)"
        io.puts "    YYR2"
        io.puts "  end"
        io.puts
        io.puts "  def yylast : Int32"
        io.puts "    YYLAST"
        io.puts "  end"
        io.puts
        io.puts "  def yyntokens : Int32"
        io.puts "    YYNTOKENS"
        io.puts "  end"
        io.puts
        io.puts "  def yypact_ninf : Int32"
        io.puts "    YYPACT_NINF"
        io.puts "  end"
        io.puts
        io.puts "  def yytable_ninf : Int32"
        io.puts "    YYTABLE_NINF"
        io.puts "  end"
        io.puts
        io.puts "  def yyfinal : Int32"
        io.puts "    YYFINAL"
        io.puts "  end"
        io.puts
        io.puts "  def error_symbol : Int32"
        io.puts "    YYERROR"
        io.puts "  end"
        io.puts
        io.puts "  def eof_symbol : Int32"
        io.puts "    YYEOF"
        io.puts "  end"
        io.puts
      end

      private def emit_reduce_method(io : IO)
        io.puts "  def reduce(rule : Int32, values : Array(Object?), locations : Array(Lrama::Runtime::Location?)) : Object?"
        io.puts "    case rule"
        io.puts "    when 0"
        io.puts "      nil"
        @grammar.rules.each_with_index do |rule, index|
          rule_id = index + 1
          io.puts "    when #{rule_id}"
          emit_rule_comment(io, rule)
          if code = rule.token_code
            emit_action_comment(io, code)
          end
          if rule.rhs.empty?
            io.puts "      nil"
          else
            io.puts "      values.last?"
          end
        end
        io.puts "    else"
        io.puts "      nil"
        io.puts "    end"
        io.puts "  end"
        io.puts
      end

      private def emit_rule_comment(io : IO, rule : Grammar::Rule)
        io.puts "      # #{rule.display_name}"
      end

      private def emit_action_comment(io : IO, code : Lexer::Token::UserCode)
        code.s_value.each_line do |line|
          io.puts "      # action: #{line}"
        end
      end

      private def format_array(values : Array(Int32))
        return "[] of Int32" if values.empty?
        chunks = values.each_slice(12).map do |slice|
          slice.join(", ")
        end
        if chunks.size == 1
          "[#{chunks.first}]"
        else
          "[\n    #{chunks.join(",\n    ")}\n  ]"
        end
      end
    end
  end
end
