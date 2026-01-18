require "./code/destructor_code"
require "./code/initial_action_code"
require "./code/no_reference_code"
require "./code/printer_code"
require "./code/rule_action"

module Lrama
  class Grammar
    class Code
      getter type : ::Symbol
      getter token_code : Lexer::Token::UserCode

      def initialize(@type : ::Symbol, @token_code : Lexer::Token::UserCode)
      end

      def s_value
        token_code.s_value
      end

      def line
        token_code.line
      end

      def column
        token_code.column
      end

      def references
        token_code.references
      end

      def translated_code
        t_code = s_value.dup
        references.reverse_each do |ref|
          t_code = replace_reference(t_code, ref)
        end
        t_code
      end

      private def replace_reference(code : String, ref : Grammar::Reference)
        start = ref.first_column
        finish = ref.last_column
        replacement = reference_to_c(ref)

        head = start > 0 ? (code.byte_slice(0, start) || "") : ""
        tail_len = code.bytesize - finish
        tail = tail_len > 0 ? (code.byte_slice(finish, tail_len) || "") : ""

        "#{head}#{replacement}#{tail}"
      end

      private def reference_to_c(ref : Grammar::Reference)
        raise NotImplementedError.new("#reference_to_c is not implemented")
      end
    end
  end
end
