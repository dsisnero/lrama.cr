module Lrama
  class Grammar
    class Rule
      property id : Int32?
      property _lhs : Lexer::Token::Base?
      property lhs : Grammar::Symbol?
      property lhs_tag : Lexer::Token::Tag?
      property _rhs : Array(Lexer::Token::Base)
      property rhs : Array(Grammar::Symbol)
      property token_code : Lexer::Token::UserCode?
      property position_in_original_rule_rhs : Int32?
      property nullable : Bool?
      property precedence_sym : Grammar::Symbol?
      property lineno : Int32?
      property original_rule : Rule?

      def initialize(
        @id : Int32? = nil,
        @_lhs : Lexer::Token::Base? = nil,
        @lhs : Grammar::Symbol? = nil,
        @lhs_tag : Lexer::Token::Tag? = nil,
        @_rhs : Array(Lexer::Token::Base) = [] of Lexer::Token::Base,
        @rhs : Array(Grammar::Symbol) = [] of Grammar::Symbol,
        @token_code : Lexer::Token::UserCode? = nil,
        @position_in_original_rule_rhs : Int32? = nil,
        @nullable : Bool? = nil,
        @precedence_sym : Grammar::Symbol? = nil,
        @lineno : Int32? = nil,
      )
        @original_rule = nil
      end

      def display_name
        lhs_name = lhs.try(&.id.s_value) || _lhs.try(&.s_value) || ""
        rhs_names =
          if empty_rule?
            "%empty"
          else
            rhs.map(&.id.s_value).join(" ")
          end
        "#{lhs_name} -> #{rhs_names}"
      end

      def display_name_without_action
        lhs_name = lhs.try(&.id.s_value) || _lhs.try(&.s_value) || ""
        rhs_names =
          if empty_rule?
            "%empty"
          else
            rhs.compact_map { |sym| sym.first_set.empty? ? nil : sym.id.s_value }.join(" ")
          end
        "#{lhs_name} -> #{rhs_names}"
      end

      def as_comment
        lhs_name = lhs.try(&.id.s_value) || _lhs.try(&.s_value) || ""
        rhs_names =
          if empty_rule?
            "%empty"
          else
            rhs.map(&.display_name).join(" ")
          end
        "#{lhs_name}: #{rhs_names}"
      end

      def with_actions
        "#{display_name} {#{token_code.try(&.s_value)}}"
      end

      def empty_rule?
        rhs.empty?
      end

      def precedence
        precedence_sym.try(&.precedence)
      end

      def initial_rule?
        id == 0
      end

      def contains_at_reference?
        token_code.try(&.references.any? { |ref| ref.type == :at }) || false
      end
    end
  end
end
