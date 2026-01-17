module Lrama
  class Lexer
    class GrammarFile
      @lines : Array(String)?

      getter path : String
      getter text : String

      def initialize(@path : String, text : String)
        @text = text
      end

      def inspect(io : IO)
        io << "<" << self.class.name << ": @path=" << path
        io << ", @text=" << short_text.inspect << ">"
      end

      def ==(other : GrammarFile)
        self.class == other.class && path == other.path
      end

      def lines
        @lines ||= text.split("\n")
      end

      private def short_text
        text.size <= 50 ? text : "#{text[0, 48]}..."
      end
    end
  end
end
