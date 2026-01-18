module Lrama
  class Grammar
    module Parameterized
      class Rhs
        property symbols : Array(Lexer::Token::Base)
        property user_code : Lexer::Token::UserCode?
        property precedence_sym : Lexer::Token::Base?

        def initialize
          @symbols = [] of Lexer::Token::Base
          @user_code = nil
          @precedence_sym = nil
        end

        def resolve_user_code(bindings : Grammar::Binding)
          return unless user_code

          resolved = Lexer::Token::UserCode.new(user_code.s_value, location: user_code.location)
          var_to_arg = {} of String => String

          symbols.each do |sym|
            resolved_sym = bindings.resolve_symbol(sym)
            var_to_arg[sym.s_value] = resolved_sym.s_value if resolved_sym != sym
          end

          var_to_arg.each do |var, arg|
            resolved.references.each do |ref|
              ref.name = arg if ref.name == var
            end
          end

          resolved
        end
      end
    end
  end
end
