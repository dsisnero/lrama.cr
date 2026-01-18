module Lrama
  class Grammar
    class Code
      class DestructorCode < Code
        def initialize(type : ::Symbol, token_code : Lexer::Token::UserCode, @tag : Lexer::Token::Tag)
          super(type, token_code)
        end

        private def reference_to_c(ref : Grammar::Reference)
          case
          when ref.type == :dollar && ref.name == "$"
            member = @tag.member
            "((*yyvaluep).#{member})"
          when ref.type == :at && ref.name == "$"
            "(*yylocationp)"
          when ref.type == :index && ref.name == "$"
            raise "$:#{ref.value} can not be used in #{type}."
          when ref.type == :dollar
            raise "$#{ref.value} can not be used in #{type}."
          when ref.type == :at
            raise "@#{ref.value} can not be used in #{type}."
          when ref.type == :index
            raise "$:#{ref.value} can not be used in #{type}."
          else
            raise "Unexpected. #{self}, #{ref}"
          end
        end
      end
    end
  end
end
