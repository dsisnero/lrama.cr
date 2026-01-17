module Lrama
  class Lexer
    module Token
      class UserCode < Base
        property tag : Tag?

        def references
          [] of String
        end

        def code
          s_value
        end
      end
    end
  end
end
