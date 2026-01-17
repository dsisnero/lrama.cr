module Lrama
  class Grammar
    getter declarations_tokens : Array(Lexer::TokenValue)
    getter rules_tokens : Array(Lexer::TokenValue)
    getter epilogue_tokens : Array(Lexer::TokenValue)
    property prologue : String?
    property? required : Bool
    property define : Hash(String, String?)
    property expect : Int32?
    property? no_stdlib : Bool
    property? locations : Bool

    def initialize
      @declarations_tokens = [] of Lexer::TokenValue
      @rules_tokens = [] of Lexer::TokenValue
      @epilogue_tokens = [] of Lexer::TokenValue
      @prologue = nil
      @required = false
      @define = {} of String => String?
      @expect = nil
      @no_stdlib = false
      @locations = false
    end

    def tokens_for(section : Symbol)
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
  end
end
