module Lrama
  class Grammar
    class Code
      class NoReferenceCode < Code
        private def reference_to_c(ref : Grammar::Reference)
          case
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
