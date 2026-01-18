module Lrama
  class State
    struct Item
      getter rule : Grammar::Rule
      getter position : Int32

      def initialize(@rule : Grammar::Rule, @position : Int32)
      end

      def hash
        {rule_id, position}.hash
      end

      def ==(other : Item)
        rule_id == other.rule_id && position == other.position
      end

      def rule_id
        rule.id || raise "Rule id missing"
      end

      def empty_rule?
        rule.empty_rule?
      end

      def number_of_rest_symbols
        rhs.size - position
      end

      def next_sym
        rhs[position]?
      end

      def next_next_sym
        rhs[position + 1]?
      end

      def previous_sym
        rhs[position - 1]?
      end

      def end_of_rule?
        rhs.size == position
      end

      def beginning_of_rule?
        position == 0
      end

      def start_item?
        rule.initial_rule? && beginning_of_rule?
      end

      def new_by_next_position
        Item.new(rule, position + 1)
      end

      def symbols_before_dot
        rhs[0...position]
      end

      def symbols_after_dot
        rhs[position..-1] || [] of Grammar::Symbol
      end

      def symbols_after_transition
        rhs[(position + 1)..-1] || [] of Grammar::Symbol
      end

      def to_s
        "#{lhs.id.s_value}: #{display_name}"
      end

      def display_name
        r = rhs.map(&.display_name)
        r.insert(position, "•")
        "#{r.join(" ")}  (rule #{rule_id})"
      end

      def display_rest
        r = symbols_after_dot.map(&.display_name).join(" ")
        ". #{r}  (rule #{rule_id})"
      end

      def predecessor_item_of?(other : Item)
        rule_id == other.rule_id && position == other.position - 1
      end

      private def lhs
        rule.lhs || raise "Rule lhs missing"
      end

      private def rhs
        rule.rhs
      end
    end
  end
end
