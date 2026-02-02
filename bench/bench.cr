require "benchmark"

require "../src/lrama"

GRAMMAR_PATH = ENV["LRAMA_BENCH_GRAMMAR"]? || File.expand_path("../spec/fixtures/common/nullable.y", __DIR__)
GRAMMAR_TEXT = File.read(GRAMMAR_PATH)

private def lex(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new(GRAMMAR_PATH, text)
  lexer = Lrama::Lexer.new(grammar_file)
  while lexer.next_token
  end
end

private def parse_grammar(text : String)
  grammar_file = Lrama::Lexer::GrammarFile.new(GRAMMAR_PATH, text)
  grammar = Lrama::GrammarParser.new(Lrama::Lexer.new(grammar_file)).parse
  grammar.prepare
  grammar
end

private def compute_states(text : String)
  grammar = parse_grammar(text)
  states = Lrama::States.new(grammar, Lrama::Tracer.new)
  states.compute
  states
end

class BenchParser < Lrama::Runtime::Parser
  ID    = 2
  YYEOF = 0
  YYERR = 1

  YYPACT       = [0, 3, -1000]
  YYPGOTO      = [-1000]
  YYDEFACT     = [0, 0, 0]
  YYDEFGOTO    = [2]
  YYTABLE      = [-1000, -1000, 1, -1, -1000, -1000]
  YYCHECK      = [-1, -1, 2, 0, -1, -1]
  YYR1         = [0, 3]
  YYR2         = [1, 1]
  YYLAST       =     5
  YYPACT_NINF  = -1000
  YYTABLE_NINF = -1000
  YYFINAL      =     2
  YYNTOKENS    =     3

  def yypact : Array(Int32)
    YYPACT
  end

  def yypgoto : Array(Int32)
    YYPGOTO
  end

  def yydefact : Array(Int32)
    YYDEFACT
  end

  def yydefgoto : Array(Int32)
    YYDEFGOTO
  end

  def yytable : Array(Int32)
    YYTABLE
  end

  def yycheck : Array(Int32)
    YYCHECK
  end

  def yyr1 : Array(Int32)
    YYR1
  end

  def yyr2 : Array(Int32)
    YYR2
  end

  def yylast : Int32
    YYLAST
  end

  def yyntokens : Int32
    YYNTOKENS
  end

  def yypact_ninf : Int32
    YYPACT_NINF
  end

  def yytable_ninf : Int32
    YYTABLE_NINF
  end

  def yyfinal : Int32
    YYFINAL
  end

  def error_symbol : Int32
    YYERR
  end

  def eof_symbol : Int32
    YYEOF
  end

  def error_recovery? : Bool
    false
  end

  def reduce(rule : Int32, values : Array(Lrama::Runtime::Value), locations : Array(Lrama::Runtime::Location?)) : Lrama::Runtime::Value
    _ = rule
    _ = values
    _ = locations
    nil
  end
end

class BenchLexer
  include Lrama::Runtime::Lexer

  def initialize(@tokens : Array(Lrama::Runtime::Token))
    @index = 0
  end

  def next_token : Lrama::Runtime::Token
    token = @tokens[@index]?
    if token
      @index += 1
      token
    else
      Lrama::Runtime::Token.new(BenchParser::YYEOF)
    end
  end
end

private def parse_runtime
  parser = BenchParser.new
  lexer = BenchLexer.new([
    Lrama::Runtime::Token.new(BenchParser::ID),
    Lrama::Runtime::Token.new(BenchParser::YYEOF),
  ])
  parser.parse(lexer)
end

Benchmark.ips do |x|
  x.report("lexer") { lex(GRAMMAR_TEXT) }
  x.report("grammar.parse") { parse_grammar(GRAMMAR_TEXT) }
  x.report("states.compute") { compute_states(GRAMMAR_TEXT) }
  x.report("runtime.parse") { parse_runtime }
end
