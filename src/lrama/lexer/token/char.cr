module Lrama
  class Lexer
    module Token
      class Char < Base
        def validate
          validate_ascii_code_range
        end

        private def validate_ascii_code_range
          return if s_value.ascii_only?
          errors << "Invalid character: `#{s_value}`. Only ASCII characters are allowed."
        end
      end
    end
  end
end
