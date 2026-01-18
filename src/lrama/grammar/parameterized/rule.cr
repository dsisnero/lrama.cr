module Lrama
  class Grammar
    module Parameterized
      class Rule
        getter name : String
        getter parameters : Array(Lexer::Token::Base)
        getter rhs : Array(Rhs)
        getter required_parameters_count : Int32
        getter tag : Lexer::Token::Tag?

        def initialize(
          @name : String,
          @parameters : Array(Lexer::Token::Base),
          @rhs : Array(Rhs),
          @tag : Lexer::Token::Tag? = nil,
          @inline : Bool = false,
        )
          @required_parameters_count = parameters.size
        end

        def to_s
          "#{@name}(#{@parameters.map(&.s_value).join(", ")})"
        end

        def inline?
          @inline
        end
      end
    end
  end
end
