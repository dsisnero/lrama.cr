require "./spec_helper"

private def build_location(path : String, line : Int32 = 1, column : Int32 = 0)
  grammar_file = Lrama::Lexer::GrammarFile.new(path, "")
  Lrama::Lexer::Location.new(
    grammar_file: grammar_file,
    first_line: line,
    first_column: column,
    last_line: line,
    last_column: column + 1
  )
end

describe Lrama::Grammar do
  describe "#validate!" do
    it "does not raise for valid precedence" do
      grammar = Lrama::Grammar.new
      location = build_location("valid_precedence.y")
      term = grammar.add_term(Lrama::Lexer::Token::Ident.new("expr", location: location))
      grammar.add_precedence(term, 1, "tNUMBER", 10)
      grammar.fill_symbol_number

      grammar.validate!.should be_nil
    end

    it "raises when precedence is defined for a nonterminal" do
      grammar = Lrama::Grammar.new
      location = build_location("invalid_precedence.y")
      nterm = grammar.add_nterm(Lrama::Lexer::Token::Ident.new("expression", location: location))
      grammar.add_precedence(nterm, 1, "tNUMBER", 10)
      grammar.fill_symbol_number

      expect_raises(Exception, "[BUG] Precedence expression (line: 10) is defined for nonterminal symbol (line: 1). Precedence can be defined for only terminal symbol.") do
        grammar.validate!
      end
    end

    it "raises when multiple nonterminals have precedence" do
      grammar = Lrama::Grammar.new
      location1 = build_location("invalid_precedence_multi.y", 1)
      location2 = build_location("invalid_precedence_multi.y", 2)
      nterm1 = grammar.add_nterm(Lrama::Lexer::Token::Ident.new("expression", location: location1))
      nterm2 = grammar.add_nterm(Lrama::Lexer::Token::Ident.new("statement", location: location2))
      grammar.add_precedence(nterm1, 1, "tNUMBER", 10)
      grammar.add_precedence(nterm2, 2, "tSTRING", 20)
      grammar.fill_symbol_number

      expected = "[BUG] Precedence expression (line: 10) is defined for nonterminal symbol (line: 1). Precedence can be defined for only terminal symbol.\n" \
                 "[BUG] Precedence statement (line: 20) is defined for nonterminal symbol (line: 2). Precedence can be defined for only terminal symbol."

      expect_raises(Exception, expected) do
        grammar.validate!
      end
    end

    it "raises when rule lhs is terminal" do
      grammar = Lrama::Grammar.new
      lhs_term = Lrama::Grammar::Symbol.new(
        id: Lrama::Lexer::Token::Ident.new("+", location: build_location("term_lhs.y")),
        term: true
      )
      rule = Lrama::Grammar::Rule.new(
        id: 1,
        _lhs: Lrama::Lexer::Token::Ident.new("+", location: build_location("term_lhs.y")),
        rhs: [] of Lrama::Grammar::Symbol,
        token_code: nil,
        lineno: 15
      )
      rule.lhs = lhs_term
      grammar.rules << rule
      grammar.fill_symbol_number

      expect_raises(Exception, "[BUG] LHS of + -> %empty (line: 15) is terminal symbol. It should be nonterminal symbol.") do
        grammar.validate!
      end
    end

    it "raises when multiple rules have terminal lhs" do
      grammar = Lrama::Grammar.new
      lhs1 = Lrama::Grammar::Symbol.new(
        id: Lrama::Lexer::Token::Ident.new("+", location: build_location("multi_term_lhs.y", 1)),
        term: true
      )
      lhs2 = Lrama::Grammar::Symbol.new(
        id: Lrama::Lexer::Token::Ident.new("expr", location: build_location("multi_term_lhs.y", 2)),
        term: false
      )
      lhs3 = Lrama::Grammar::Symbol.new(
        id: Lrama::Lexer::Token::Ident.new("-", location: build_location("multi_term_lhs.y", 3)),
        term: true
      )

      rule1 = Lrama::Grammar::Rule.new(
        id: 1,
        _lhs: Lrama::Lexer::Token::Ident.new("+", location: build_location("multi_term_lhs.y", 1)),
        rhs: [] of Lrama::Grammar::Symbol,
        token_code: nil,
        lineno: 15
      )
      rule2 = Lrama::Grammar::Rule.new(
        id: 2,
        _lhs: Lrama::Lexer::Token::Ident.new("expr", location: build_location("multi_term_lhs.y", 2)),
        rhs: [] of Lrama::Grammar::Symbol,
        token_code: nil,
        lineno: 20
      )
      rule3 = Lrama::Grammar::Rule.new(
        id: 3,
        _lhs: Lrama::Lexer::Token::Ident.new("-", location: build_location("multi_term_lhs.y", 3)),
        rhs: [] of Lrama::Grammar::Symbol,
        token_code: nil,
        lineno: 25
      )
      rule1.lhs = lhs1
      rule2.lhs = lhs2
      rule3.lhs = lhs3
      grammar.rules.concat([rule1, rule2, rule3])
      grammar.fill_symbol_number

      expected = "[BUG] LHS of + -> %empty (line: 15) is terminal symbol. It should be nonterminal symbol.\n" \
                 "[BUG] LHS of - -> %empty (line: 25) is terminal symbol. It should be nonterminal symbol."

      expect_raises(Exception, expected) do
        grammar.validate!
      end
    end

    it "raises for duplicated precedence declarations" do
      grammar = Lrama::Grammar.new
      location = build_location("dup_precedence.y")
      term = grammar.add_term(Lrama::Lexer::Token::Ident.new("expr", location: location))
      grammar.add_left(term, 0, "tSTRING", 7)
      grammar.add_precedence(term, 1, "tSTRING", 8)
      grammar.fill_symbol_number

      expect_raises(Exception, "%precedence redeclaration for tSTRING (line: 8) previous declaration was %left (line: 7)") do
        grammar.validate!
      end
    end

    it "raises for multiple duplicated precedence declarations" do
      grammar = Lrama::Grammar.new
      location = build_location("dup_precedence_multi.y")
      term = grammar.add_term(Lrama::Lexer::Token::Ident.new("expr", location: location))
      grammar.add_left(term, 0, "tSTRING", 7)
      grammar.add_precedence(term, 1, "tSTRING", 8)
      grammar.add_nonassoc(term, 3, "tSTRING", 10)
      grammar.fill_symbol_number

      expected = "%precedence redeclaration for tSTRING (line: 8) previous declaration was %left (line: 7)\n" \
                 "%nonassoc redeclaration for tSTRING (line: 10) previous declaration was %left (line: 7)"

      expect_raises(Exception, expected) do
        grammar.validate!
      end
    end

    it "raises for duplicated precedence across multiple tokens" do
      grammar = Lrama::Grammar.new
      location = build_location("dup_precedence_multi_token.y")
      term = grammar.add_term(Lrama::Lexer::Token::Ident.new("expr", location: location))
      grammar.add_left(term, 0, "tSTRING", 7)
      grammar.add_precedence(term, 1, "tSTRING", 8)
      grammar.add_left(term, 2, "tNUMBER", 9)
      grammar.add_nonassoc(term, 3, "tNUMBER", 10)
      grammar.fill_symbol_number

      error = expect_raises(Exception) do
        grammar.validate!
      end
      message = error.message || ""
      message.includes?("%precedence redeclaration for tSTRING (line: 8)").should be_true
      message.includes?("%nonassoc redeclaration for tNUMBER (line: 10)").should be_true
      message.lines.size.should eq 2
    end

    it "only reports duplicated tokens when mixed with unique tokens" do
      grammar = Lrama::Grammar.new
      location = build_location("dup_precedence_mix.y")
      term = grammar.add_term(Lrama::Lexer::Token::Ident.new("expr", location: location))
      grammar.add_left(term, 0, "tSTRING", 7)
      grammar.add_precedence(term, 1, "tSTRING", 8)
      grammar.add_nonassoc(term, 2, "tSTRING", 10)
      grammar.add_left(term, 3, "tNUMBER", 7)
      grammar.add_nonassoc(term, 4, "tNUMBER", 10)
      grammar.add_right(term, 5, "tIDENT", 9)
      grammar.fill_symbol_number

      error = expect_raises(Exception) do
        grammar.validate!
      end
      message = error.message || ""
      message.includes?("tSTRING").should be_true
      message.includes?("tNUMBER").should be_true
      message.includes?("tIDENT").should be_false
    end
  end
end
