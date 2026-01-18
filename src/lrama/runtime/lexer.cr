module Lrama
  module Runtime
    module Lexer
      abstract def next_token : Token
    end
  end
end
