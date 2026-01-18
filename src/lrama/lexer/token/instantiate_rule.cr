module Lrama
  class Lexer
    module Token
      class InstantiateRule < Base
        getter args : Array(Base)
        getter lhs_tag : Tag?

        def initialize(
          s_value : String,
          location : Location,
          @args : Array(Base) = [] of Base,
          @lhs_tag : Tag? = nil,
          alias_name : String? = nil,
        )
          super(s_value: s_value, location: location, alias_name: alias_name)
        end

        def rule_name
          s_value
        end

        def args_count
          args.size
        end
      end
    end
  end
end
