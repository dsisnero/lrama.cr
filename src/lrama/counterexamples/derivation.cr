module Lrama
  class Counterexamples
    class Derivation
      getter item : State::Item
      getter left : Derivation?
      property right : Derivation?

      def initialize(@item : State::Item, @left : Derivation?)
      end

      def to_s
        "#<Derivation(#{item.display_name})>"
      end

      def inspect
        to_s
      end

      def render_strings_for_report
        result = [] of String
        render_for_report(self, 0, result, 0)
        result.map(&.rstrip)
      end

      def render_for_report
        render_strings_for_report.join("\n")
      end

      private def render_for_report(derivation : Derivation, offset : Int32, strings : Array(String), index : Int32)
        item = derivation.item
        if strings[index]?
          strings[index] += " " * (offset - strings[index].size)
        else
          strings[index] = " " * offset
        end

        str = strings[index]
        str += "#{item.rule_id}: #{item.symbols_before_dot.map(&.display_name).join(" ")} "

        left = derivation.left
        if left
          len = str.size
          next_sym = item.next_sym || raise "Next symbol missing"
          str += "#{next_sym.display_name}"
          length = render_for_report(left, len, strings, index + 1)
          str += " " * (length - str.size) if length > str.size
        else
          str += " • #{item.symbols_after_dot.map(&.display_name).join(" ")} "
          return str.size
        end

        right = derivation.right
        right_left = right.try(&.left)
        if right_left
          length = render_for_report(right_left, str.size, strings, index + 1)
          remainder = item.symbols_after_dot[1..-1] || [] of Grammar::Symbol
          str += "#{remainder.map(&.display_name).join(" ")} "
          str += " " * (length - str.size) if length > str.size
        elsif item.next_next_sym
          remainder = item.symbols_after_dot[1..-1] || [] of Grammar::Symbol
          str += "#{remainder.map(&.display_name).join(" ")} "
        end

        str.size
      end
    end
  end
end
