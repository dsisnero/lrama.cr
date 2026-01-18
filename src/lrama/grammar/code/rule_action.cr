module Lrama
  class Grammar
    class Code
      class RuleAction < Code
        def initialize(type : ::Symbol, token_code : Lexer::Token::UserCode, @rule : Rule)
          super(type, token_code)
        end

        # ameba:disable Metrics/CyclomaticComplexity
        private def reference_to_c(ref : Grammar::Reference)
          case
          when ref.type == :dollar && ref.name == "$"
            tag = ref.ex_tag || lhs.tag
            raise_tag_not_found_error(ref) unless tag
            "(yyval.#{tag.member})"
          when ref.type == :at && ref.name == "$"
            "(yyloc)"
          when ref.type == :index && ref.name == "$"
            raise "$:$ is not supported"
          when ref.type == :dollar
            index = ref.index || raise "Reference index missing. #{ref}"
            i = -position_in_rhs + index
            tag = ref.ex_tag || rhs[index - 1].tag
            raise_tag_not_found_error(ref) unless tag
            "(yyvsp[#{i}].#{tag.member})"
          when ref.type == :at
            index = ref.index || raise "Reference index missing. #{ref}"
            i = -position_in_rhs + index
            "(yylsp[#{i}])"
          when ref.type == :index
            index = ref.index || raise "Reference index missing. #{ref}"
            i = -position_in_rhs + index
            "(#{i} - 1)"
          else
            raise "Unexpected. #{self}, #{ref}"
          end
        end

        # ameba:enable Metrics/CyclomaticComplexity

        private def position_in_rhs
          @rule.position_in_original_rule_rhs || @rule.rhs.size
        end

        private def rhs
          (original = @rule.original_rule) ? original.rhs : @rule.rhs
        end

        private def lhs
          @rule.lhs || raise "Rule LHS missing for action translation"
        end

        private def raise_tag_not_found_error(ref : Grammar::Reference)
          raise "Tag is not specified for '$#{ref.value}' in '#{@rule.display_name}'"
        end
      end
    end
  end
end
