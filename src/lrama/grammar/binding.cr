module Lrama
  class Grammar
    class Binding
      @actual_args : Array(Lexer::Token::Base)
      @param_to_arg : Hash(String, Lexer::Token::Base)

      def initialize(params : Array(Lexer::Token::Base), actual_args : Array(Lexer::Token::Base))
        @actual_args = actual_args
        @param_to_arg = build_param_to_arg(params, @actual_args)
      end

      def resolve_symbol(sym : Lexer::Token::Base) : Lexer::Token::Base
        return create_instantiate_rule(sym) if sym.is_a?(Lexer::Token::InstantiateRule)
        find_arg_for_param(sym)
      end

      def concatenated_args_str(token : Lexer::Token::InstantiateRule)
        "#{token.rule_name}_#{format_args(token)}"
      end

      private def create_instantiate_rule(sym : Lexer::Token::InstantiateRule) : Lexer::Token::InstantiateRule
        Lexer::Token::InstantiateRule.new(
          sym.s_value,
          location: sym.location,
          args: resolve_args(sym.args),
          lhs_tag: sym.lhs_tag
        )
      end

      private def resolve_args(args : Array(Lexer::Token::Base)) : Array(Lexer::Token::Base)
        args.map { |arg| resolve_symbol(arg) }
      end

      private def find_arg_for_param(sym : Lexer::Token::Base) : Lexer::Token::Base
        if arg = @param_to_arg[sym.s_value]?
          resolved = arg.dup
          resolved.alias_name = sym.alias_name
          return resolved
        end
        sym
      end

      private def build_param_to_arg(params : Array(Lexer::Token::Base), actual_args : Array(Lexer::Token::Base))
        params.zip(actual_args).to_h { |param, arg| {param.s_value, arg} }
      end

      private def format_args(token : Lexer::Token::InstantiateRule)
        token_to_args_s_values(token).join('_')
      end

      private def token_to_args_s_values(token : Lexer::Token::InstantiateRule)
        token.args.flat_map do |arg|
          resolved = resolve_symbol(arg)
          if resolved.is_a?(Lexer::Token::InstantiateRule)
            [resolved.s_value] + resolved.args.map(&.s_value)
          else
            [resolved.s_value]
          end
        end
      end
    end
  end
end
