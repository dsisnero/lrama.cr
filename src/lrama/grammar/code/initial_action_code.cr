module Lrama
  class Grammar
    class Code
      class InitialActionCode < Code
        private def reference_to_c(ref : Grammar::Reference)
          case
          when ref.type == :dollar && ref.name == "$"
            "yylval"
          when ref.type == :at && ref.name == "$"
            "yylloc"
          when ref.type == :index && ref.name == "$"
            raise "$:#{ref.value} can not be used in initial_action."
          when ref.type == :dollar
            raise "$#{ref.value} can not be used in initial_action."
          when ref.type == :at
            raise "@#{ref.value} can not be used in initial_action."
          when ref.type == :index
            raise "$:#{ref.value} can not be used in initial_action."
          else
            raise "Unexpected. #{self}, #{ref}"
          end
        end
      end
    end
  end
end
