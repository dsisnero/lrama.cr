require "./spec_helper"

private def next_token(lexer)
  lexer.next_token
end

private def expect_token(lexer, kind, value = nil)
  token = next_token(lexer).as(Lrama::Lexer::TokenValue)
  token[0].should eq(kind)
  value.try { |expected| token[1].s_value.should eq(expected) }
  token
end

private def fixture_path(relative_path)
  File.join(__DIR__, "fixtures", relative_path)
end

describe Lrama::Lexer do
  describe "#next_token" do
    it "lexes basic.y" do
      path = fixture_path("common/basic.y")
      grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
      lexer = Lrama::Lexer.new(grammar_file)

      expect_token(lexer, "%require", "%require")
      expect_token(lexer, :STRING, "\"3.0\"")
      expect_token(lexer, "%{", "%{")

      lexer.status = :c_declaration
      lexer.end_symbol = "%}"
      token = expect_token(lexer, :C_DECLARATION, "\n// Prologue\n")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 7,
        first_column: 2,
        last_line: 9,
        last_column: 0
      )
      lexer.status = :initial

      expect_token(lexer, "%}", "%}")
      expect_token(lexer, "%expect", "%expect")
      expect_token(lexer, :INTEGER, "0")
      expect_token(lexer, "%define", "%define")
      expect_token(lexer, :IDENTIFIER, "api.pure")
      expect_token(lexer, "%define", "%define")
      expect_token(lexer, :IDENTIFIER, "parse.error")
      expect_token(lexer, :IDENTIFIER, "verbose")
      expect_token(lexer, "%define", "%define")
      expect_token(lexer, :IDENTIFIER, "api.prefix")
      expect_token(lexer, "{", "{")
      expect_token(lexer, :IDENTIFIER, "prefix")
      expect_token(lexer, "}", "}")
      expect_token(lexer, "%printer", "%printer")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, "\n    print_int();\n")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 16,
        first_column: 10,
        last_line: 18,
        last_column: 0
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, :TAG, "<int>")
      expect_token(lexer, "%printer", "%printer")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, "\n    print_token();\n")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 19,
        first_column: 10,
        last_line: 21,
        last_column: 0
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, :IDENTIFIER, "tNUMBER")
      expect_token(lexer, :IDENTIFIER, "tSTRING")
      expect_token(lexer, "%lex-param", "%lex-param")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, "struct lex_params *p")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 23,
        first_column: 12,
        last_line: 23,
        last_column: 32
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, "%parse-param", "%parse-param")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, "struct parse_params *p")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 24,
        first_column: 14,
        last_line: 24,
        last_column: 36
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, "%initial-action", "%initial-action")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, "\n    initial_action_func(@$);\n")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 27,
        first_column: 1,
        last_line: 29,
        last_column: 0
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, ";", ";")
      expect_token(lexer, ";", ";")
      expect_token(lexer, "%union", "%union")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, "\n    int i;\n    long l;\n    char *str;\n")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 31,
        first_column: 8,
        last_line: 35,
        last_column: 0
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :IDENTIFIER, "EOI")
      expect_token(lexer, :INTEGER, "0")
      expect_token(lexer, :STRING, "\"EOI\"")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :CHARACTER, "'\\\\'")
      expect_token(lexer, :STRING, "\"backslash\"")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :CHARACTER, "'\\13'")
      expect_token(lexer, :STRING, "\"escaped vertical tab\"")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :IDENTIFIER, "keyword_class")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :IDENTIFIER, "keyword_class2")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :TAG, "<l>")
      expect_token(lexer, :IDENTIFIER, "tNUMBER")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :TAG, "<str>")
      expect_token(lexer, :IDENTIFIER, "tSTRING")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :IDENTIFIER, "keyword_end")
      expect_token(lexer, :STRING, "\"end\"")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :IDENTIFIER, "tPLUS")
      expect_token(lexer, :STRING, "\"+\"")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :IDENTIFIER, "tMINUS")
      expect_token(lexer, :STRING, "\"-\"")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :IDENTIFIER, "tEQ")
      expect_token(lexer, :STRING, "\"=\"")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :IDENTIFIER, "tEQEQ")
      expect_token(lexer, :STRING, "\"==\"")
      expect_token(lexer, "%type", "%type")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :IDENTIFIER, "class")
      expect_token(lexer, "%nonassoc", "%nonassoc")
      expect_token(lexer, :IDENTIFIER, "tEQEQ")
      expect_token(lexer, "%left", "%left")
      expect_token(lexer, :IDENTIFIER, "tPLUS")
      expect_token(lexer, :IDENTIFIER, "tMINUS")
      expect_token(lexer, :CHARACTER, "'>'")
      expect_token(lexer, "%right", "%right")
      expect_token(lexer, :IDENTIFIER, "tEQ")
      expect_token(lexer, "%%", "%%")
      expect_token(lexer, :IDENT_COLON, "program")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "class")
      expect_token(lexer, "|", "|")
      expect_token(lexer, :CHARACTER, "'+'")
      expect_token(lexer, :IDENTIFIER, "strings_1")
      expect_token(lexer, "|", "|")
      expect_token(lexer, :CHARACTER, "'-'")
      expect_token(lexer, :IDENTIFIER, "strings_2")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "class")
      expect_token(lexer, ":", ":")
      expect_token(lexer, "%prec", "%prec")
      expect_token(lexer, :IDENTIFIER, "tPLUS")
      expect_token(lexer, :IDENTIFIER, "keyword_class")
      expect_token(lexer, :IDENTIFIER, "tSTRING")
      expect_token(lexer, :IDENTIFIER, "keyword_end")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, " code 1 ")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 64,
        first_column: 11,
        last_line: 64,
        last_column: 19
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, "|", "|")
      expect_token(lexer, :IDENTIFIER, "keyword_class")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, " code 2 ")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 65,
        first_column: 23,
        last_line: 65,
        last_column: 31
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, :IDENTIFIER, "tSTRING")
      expect_token(lexer, :CHARACTER, "'!'")
      expect_token(lexer, :IDENTIFIER, "keyword_end")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, " code 3 ")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 65,
        first_column: 58,
        last_line: 65,
        last_column: 66
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, "%prec", "%prec")
      expect_token(lexer, :STRING, "\"=\"")
      expect_token(lexer, "|", "|")
      expect_token(lexer, :IDENTIFIER, "keyword_class")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, " code 4 ")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 66,
        first_column: 23,
        last_line: 66,
        last_column: 31
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, :IDENTIFIER, "tSTRING")
      expect_token(lexer, :CHARACTER, "'?'")
      expect_token(lexer, :IDENTIFIER, "keyword_end")
      expect_token(lexer, "{", "{")

      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      token = expect_token(lexer, :C_DECLARATION, " code 5 ")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 66,
        first_column: 58,
        last_line: 66,
        last_column: 66
      )
      lexer.status = :initial

      expect_token(lexer, "}", "}")
      expect_token(lexer, "%prec", "%prec")
      expect_token(lexer, :CHARACTER, "'>'")
      expect_token(lexer, ";", ";")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "strings_1")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "string_1")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "strings_2")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "string_1")
      expect_token(lexer, "|", "|")
      expect_token(lexer, :IDENTIFIER, "string_2")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "string_1")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "string")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "string_2")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "string")
      expect_token(lexer, :CHARACTER, "'+'")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "string")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "tSTRING")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "unused")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "tNUMBER")
      expect_token(lexer, ";", ";")
      expect_token(lexer, "%%", "%%")
      next_token(lexer).should be_nil
    end

    it "lexes nullable.y" do
      path = fixture_path("common/nullable.y")
      grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
      lexer = Lrama::Lexer.new(grammar_file)

      expect_token(lexer, "%require", "%require")
      expect_token(lexer, :STRING, "\"3.0\"")
      expect_token(lexer, "%{", "%{")

      lexer.status = :c_declaration
      lexer.end_symbol = "%}"
      token = expect_token(lexer, :C_DECLARATION, "\n// Prologue\n")
      token[1].location.should eq Lrama::Lexer::Location.new(
        grammar_file: grammar_file,
        first_line: 7,
        first_column: 2,
        last_line: 9,
        last_column: 0
      )
      lexer.status = :initial

      expect_token(lexer, "%}", "%}")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :IDENTIFIER, "tNUMBER")
      expect_token(lexer, "%%", "%%")
      expect_token(lexer, :IDENT_COLON, "program")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "stmt")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "stmt")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "expr")
      expect_token(lexer, :IDENTIFIER, "opt_semicolon")
      expect_token(lexer, "|", "|")
      expect_token(lexer, :IDENTIFIER, "opt_expr")
      expect_token(lexer, :IDENTIFIER, "opt_colon")
      expect_token(lexer, "|", "|")
      expect_token(lexer, "%empty", "%empty")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "expr")
      expect_token(lexer, ":", ":")
      expect_token(lexer, :IDENTIFIER, "tNUMBER")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "opt_expr")
      expect_token(lexer, ":", ":")
      expect_token(lexer, "|", "|")
      expect_token(lexer, :IDENTIFIER, "expr")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "opt_semicolon")
      expect_token(lexer, ":", ":")
      expect_token(lexer, "|", "|")
      expect_token(lexer, :CHARACTER, "';'")
      expect_token(lexer, ";", ";")
      expect_token(lexer, :IDENT_COLON, "opt_colon")
      expect_token(lexer, ":", ":")
      expect_token(lexer, "%empty", "%empty")
      expect_token(lexer, "|", "|")
      expect_token(lexer, :CHARACTER, "'.'")
      expect_token(lexer, ";", ";")
      expect_token(lexer, "%%", "%%")
      next_token(lexer).should be_nil
    end

    it "lexes precedence.y" do
      path = fixture_path("common/precedence.y")
      grammar_file = Lrama::Lexer::GrammarFile.new(path, File.read(path))
      lexer = Lrama::Lexer.new(grammar_file)

      expect_token(lexer, "%{", "%{")
      lexer.status = :c_declaration
      lexer.end_symbol = "%}"
      expect_token(lexer, :C_DECLARATION, "\n#include <stdio.h>\n#include <stdlib.h>\n\nint yylex(void);\nvoid yyerror(const char *s);\n")
      lexer.status = :initial
      expect_token(lexer, "%}", "%}")
      expect_token(lexer, "%union", "%union")
      expect_token(lexer, "{", "{")
      lexer.status = :c_declaration
      lexer.end_symbol = "}"
      expect_token(lexer, :C_DECLARATION, "\n    int i;\n    void* p;\n")
      lexer.status = :initial
      expect_token(lexer, "}", "}")
      expect_token(lexer, "%left", "%left")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :IDENTIFIER, "PLUS")
      expect_token(lexer, :IDENTIFIER, "MINUS")
      expect_token(lexer, :TAG, "<p>")
      expect_token(lexer, :IDENTIFIER, "ADD_OP")
      expect_token(lexer, "%left", "%left")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :IDENTIFIER, "MULT")
      expect_token(lexer, :IDENTIFIER, "DIV")
      expect_token(lexer, :IDENTIFIER, "MOD")
      expect_token(lexer, :TAG, "<p>")
      expect_token(lexer, :IDENTIFIER, "MULT_OP")
      expect_token(lexer, "%left", "%left")
      expect_token(lexer, :IDENTIFIER, "DIV_OP")
      expect_token(lexer, :IDENTIFIER, "P_MULT_OP")
      expect_token(lexer, :TAG, "<p>")
      expect_token(lexer, :IDENTIFIER, "P_DIV_OP")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :IDENTIFIER, "NUMBER")
      expect_token(lexer, "%token", "%token")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :IDENTIFIER, "LPAREN")
      expect_token(lexer, :IDENTIFIER, "RPAREN")
      expect_token(lexer, "%type", "%type")
      expect_token(lexer, :TAG, "<i>")
      expect_token(lexer, :IDENTIFIER, "expr")
      expect_token(lexer, :IDENTIFIER, "term")
      expect_token(lexer, :IDENTIFIER, "factor")
      expect_token(lexer, "%%", "%%")
      expect_token(lexer, :IDENT_COLON, "program")
      expect_token(lexer, ":", ":")
    end
  end

  it "raises on unexpected token" do
    path = fixture_path("common/unexpected_token.y")
    grammar_file = Lrama::Lexer::GrammarFile.new("unexpected_token.y", File.read(path))
    lexer = Lrama::Lexer.new(grammar_file)

    expected = <<-MSG
      unexpected_token.y:5:0: Unexpected token
         5 | @invalid
           | ^
      MSG
    expect_raises(ParseError, expected) { lexer.next_token }
  end

  it "raises on unexpected C code" do
    grammar_file = Lrama::Lexer::GrammarFile.new("invalid.y", "@invalid")
    lexer = Lrama::Lexer.new(grammar_file)
    lexer.status = :c_declaration
    lexer.end_symbol = "%}"

    expected = <<-MSG
      invalid.y:1:0: Unexpected code: @invalid
         1 | @invalid
           | ^~~~~~~~
      MSG
    expect_raises(ParseError, expected) { lexer.next_token }
  end

  it "lexes line comment without newline" do
    grammar_file = Lrama::Lexer::GrammarFile.new("comment.y", "// foo")
    lexer = Lrama::Lexer.new(grammar_file)

    lexer.next_token.should be_nil
  end

  it "tracks trailing space before newline" do
    grammar_file = Lrama::Lexer::GrammarFile.new("trailing_space.y", " \n%require")
    lexer = Lrama::Lexer.new(grammar_file)

    token = lexer.next_token.as(Lrama::Lexer::TokenValue)
    token[1].location.should eq Lrama::Lexer::Location.new(
      grammar_file: grammar_file,
      first_line: 2,
      first_column: 0,
      last_line: 2,
      last_column: 8
    )
  end
end
