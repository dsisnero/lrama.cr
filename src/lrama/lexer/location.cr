module Lrama
  class Lexer
    class Location
      @text : String?
      @text_lines : Array(String)?

      getter grammar_file : GrammarFile
      getter first_line : Int32
      getter first_column : Int32
      getter last_line : Int32
      getter last_column : Int32

      def initialize(
        @grammar_file : GrammarFile,
        @first_line : Int32,
        @first_column : Int32,
        @last_line : Int32,
        @last_column : Int32,
      )
      end

      def ==(other : Location)
        self.class == other.class &&
          grammar_file == other.grammar_file &&
          first_line == other.first_line &&
          first_column == other.first_column &&
          last_line == other.last_line &&
          last_column == other.last_column
      end

      def partial_location(left : Int32, right : Int32)
        offset = -first_column
        new_first_line = -1
        new_first_column = -1
        new_last_line = -1
        new_last_column = -1

        text_lines.each_with_index do |line, index|
          new_offset = offset + line.size + 1

          if offset <= left && left <= new_offset
            new_first_line = first_line + index
            new_first_column = left - offset
          end

          if offset <= right && right <= new_offset
            new_last_line = first_line + index
            new_last_column = right - offset
          end

          offset = new_offset
        end

        Location.new(
          grammar_file: grammar_file,
          first_line: new_first_line,
          first_column: new_first_column,
          last_line: new_last_line,
          last_column: new_last_column
        )
      end

      def to_s
        "#{path} (#{first_line},#{first_column})-(#{last_line},#{last_column})"
      end

      def generate_error_message(error_message : String)
        String.build do |io|
          io << path << ':' << first_line << ':' << first_column << ": " << error_message << '\n'
          io << error_with_carets
        end
      end

      def error_with_carets
        String.build do |io|
          io << formatted_first_lineno << " | " << text << '\n'
          io << line_number_padding << " | " << carets_line
        end
      end

      private def path
        grammar_file.path
      end

      private def carets_line
        leading_whitespace + highlight_marker
      end

      private def leading_whitespace
        slice = text[0, first_column]?
        raise "Invalid first_column: #{first_column}" unless slice
        slice.gsub(/[^\t]/, ' ')
      end

      private def highlight_marker
        length = last_column - first_column
        "^" + "~" * Math.max(0, length - 1)
      end

      private def formatted_first_lineno
        first_line.to_s.rjust(4)
      end

      private def line_number_padding
        " " * formatted_first_lineno.size
      end

      private def text
        @text ||= text_lines.join("\n")
      end

      private def text_lines : Array(String)
        @text_lines ||= begin
          range = (first_line - 1)..(last_line - 1)
          slice = grammar_file.lines[range]?
          raise "#{range} is invalid" unless slice
          slice
        end
      end
    end
  end
end
