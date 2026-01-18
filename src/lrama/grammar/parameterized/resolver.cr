module Lrama
  class Grammar
    module Parameterized
      class Resolver
        property rules : Array(Rule)
        property created_lhs_list : Array(Lexer::Token::Base)

        def initialize
          @rules = [] of Rule
          @created_lhs_list = [] of Lexer::Token::Base
        end

        def add_rule(rule : Rule)
          @rules << rule
        end

        def find_rule(token : Lexer::Token::InstantiateRule)
          select_rules(@rules, token).last
        end

        def find_inline(token : Lexer::Token::Base)
          @rules.reverse.find { |rule| rule.name == token.s_value && rule.inline? }
        end

        def created_lhs(lhs_s_value : String)
          @created_lhs_list.reverse.find { |created_lhs| created_lhs.s_value == lhs_s_value }
        end

        def redefined_rules
          @rules.select do |rule|
            @rules.count do |candidate|
              candidate.name == rule.name && candidate.required_parameters_count == rule.required_parameters_count
            end > 1
          end
        end

        private def select_rules(rules : Array(Rule), token : Lexer::Token::InstantiateRule)
          rules = reject_inline_rules(rules)
          rules = select_rules_by_name(rules, token.rule_name)
          rules = rules.select { |rule| rule.required_parameters_count == token.args_count }
          raise "Invalid number of arguments. `#{token.rule_name}`" if rules.empty?
          rules
        end

        private def reject_inline_rules(rules : Array(Rule))
          rules.reject(&.inline?)
        end

        private def select_rules_by_name(rules : Array(Rule), rule_name : String)
          rules = rules.select { |rule| rule.name == rule_name }
          raise "Parameterized rule does not exist. `#{rule_name}`" if rules.empty?
          rules
        end
      end
    end
  end
end
