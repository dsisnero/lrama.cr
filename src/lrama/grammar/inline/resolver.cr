module Lrama
  class Grammar
    module Inline
      class Resolver
        def initialize(@rule_builder : Grammar::RuleBuilder)
        end

        def resolve
          resolved_builders = [] of Grammar::RuleBuilder
          @rule_builder.rhs.each_with_index do |token, index|
            if rule = @rule_builder.parameterized_resolver.find_inline(token)
              rule.rhs.each do |rhs|
                resolved_builders << build_rule(rhs, token, index, rule)
              end
              break
            end
          end
          resolved_builders
        end

        private def build_rule(
          rhs : Grammar::Parameterized::Rhs,
          token : Lexer::Token::Base,
          index : Int32,
          rule : Grammar::Parameterized::Rule,
        )
          builder = Grammar::RuleBuilder.new(
            @rule_builder.rule_counter,
            @rule_builder.midrule_action_counter,
            @rule_builder.parameterized_resolver,
            lhs_tag: @rule_builder.lhs_tag
          )
          resolve_rhs(builder, rhs, index, token, rule)
          builder.lhs = @rule_builder.lhs
          builder.line = @rule_builder.line
          builder.precedence_sym = @rule_builder.precedence_sym
          builder.user_code = replace_user_code(rhs, index)
          builder
        end

        private def resolve_rhs(
          builder : Grammar::RuleBuilder,
          rhs : Grammar::Parameterized::Rhs,
          index : Int32,
          token : Lexer::Token::Base,
          rule : Grammar::Parameterized::Rule,
        )
          @rule_builder.rhs.each_with_index do |tok, idx|
            if idx == index
              rhs.symbols.each do |sym|
                if token.is_a?(Lexer::Token::InstantiateRule)
                  bindings = Grammar::Binding.new(rule.parameters, token.args)
                  builder.add_rhs(bindings.resolve_symbol(sym))
                else
                  builder.add_rhs(sym)
                end
              end
            else
              builder.add_rhs(tok)
            end
          end
        end

        private def replace_user_code(rhs : Grammar::Parameterized::Rhs, index : Int32)
          user_code = @rule_builder.user_code
          rhs_code = rhs.user_code
          return user_code unless user_code && rhs_code

          code = user_code.s_value.gsub("$#{index + 1}", rhs_code.s_value)
          user_code.references.each do |ref|
            ref_index = ref.index
            next unless ref_index
            next if ref_index <= index
            offset = rhs.symbols.size - 1
            code = code.gsub("$#{ref_index}", "$#{ref_index + offset}")
            code = code.gsub("@#{ref_index}", "@#{ref_index + offset}")
          end
          Lexer::Token::UserCode.new(code, location: user_code.location)
        end
      end
    end
  end
end
