module Lrama
  module Runtime
    abstract class Parser
      getter? debug : Bool

      def initialize(@debug : Bool = false)
        @state_stack = [] of Int32
        @value_stack = [] of Value
        @location_stack = [] of Location?
        @error_status = 0
      end

      abstract def yypact : Array(Int32)
      abstract def yypgoto : Array(Int32)
      abstract def yydefact : Array(Int32)
      abstract def yydefgoto : Array(Int32)
      abstract def yytable : Array(Int32)
      abstract def yycheck : Array(Int32)
      abstract def yyr1 : Array(Int32)
      abstract def yyr2 : Array(Int32)
      abstract def yylast : Int32
      abstract def yyntokens : Int32
      abstract def yypact_ninf : Int32
      abstract def yytable_ninf : Int32
      abstract def yyfinal : Int32
      abstract def error_symbol : Int32
      abstract def eof_symbol : Int32
      abstract def reduce(rule : Int32, values : Array(Value), locations : Array(Location?)) : Value
      abstract def error_recovery? : Bool

      # ameba:disable Metrics/CyclomaticComplexity
      def parse(lexer : Lexer) : Int32
        reset_stacks
        state = 0
        lookahead = nil.as(Token?)
        parser_action = :push_state
        next_state = nil.as(Int32?)
        rule = nil.as(Int32?)

        loop do
          case parser_action
          when :syntax_error
            token = lookahead || Token.new(error_symbol)
            return 1 unless error_recovery?
            if @error_status == 3 && lookahead
              return 1 if lookahead.sym == eof_symbol
              lookahead = nil
            end
            if @error_status == 0
              on_error(token)
            end
            @error_status = 3
            if recovered_state = recover_from_error(token)
              state = recovered_state
              @value_stack << nil
              @location_stack << token.location
              lookahead = nil if lookahead && lookahead.sym == error_symbol
              parser_action = :push_state
            else
              return 1
            end
          when :accept
            debug_print("accept")
            return 0
          when :push_state
            debug_print("push_state #{state}")
            @state_stack << state

            if state == yyfinal
              parser_action = :accept
              next
            end

            parser_action = :decide_parser_action
            next
          when :decide_parser_action
            debug_print("decide_parser_action")
            offset = yypact[state]
            if offset == yypact_ninf
              parser_action = :yydefault
              next
            end

            lookahead ||= lexer.next_token
            token_sym = lookahead.sym
            if token_sym == error_symbol
              parser_action = :syntax_error
              next
            end

            idx = offset + token_sym
            if idx < 0 || idx > yylast
              parser_action = :yydefault
              next
            end
            if yycheck[idx] != token_sym
              parser_action = :yydefault
              next
            end

            action = yytable[idx]
            if action == yytable_ninf
              parser_action = :syntax_error
              next
            end

            if action > 0
              next_state = action
              parser_action = :yyshift
              next
            end

            rule = -action
            parser_action = :yyreduce
          when :yyshift
            raise "next_state is not set" unless next_state
            token = lookahead || raise "lookahead token is missing"
            debug_print("shift #{token.sym}")

            @value_stack << token.value
            @location_stack << token.location
            @error_status -= 1 if @error_status > 0

            lookahead = nil
            state = next_state
            next_state = nil
            parser_action = :push_state
          when :yydefault
            debug_print("yydefault")
            rule = yydefact[state]
            if rule == 0
              parser_action = :syntax_error
            else
              parser_action = :yyreduce
            end
          when :yyreduce
            raise "rule is not set" unless rule
            debug_print("reduce #{rule}")

            rhs_length = yyr2[rule]
            rhs_values = pop_values(rhs_length)
            rhs_locations = pop_locations(rhs_length)
            @state_stack.pop(rhs_length)
            state = @state_stack.last? || raise "state stack is empty after reduce"

            lhs_symbol = yyr1[rule]
            lhs_nterm = lhs_symbol - yyntokens

            value = reduce(rule, rhs_values, rhs_locations)
            location = reduce_location(rule, rhs_locations)

            offset = yypgoto[lhs_nterm]
            if offset == yypact_ninf
              state = yydefgoto[lhs_nterm]
            else
              idx = offset + state
              if idx < 0 || idx > yylast || yycheck[idx] != state
                state = yydefgoto[lhs_nterm]
              else
                state = yytable[idx]
              end
            end

            @value_stack << value
            @location_stack << location
            rule = nil
            parser_action = :push_state
          else
            raise "Unknown parser action: #{parser_action}"
          end
        end
      end

      # ameba:enable Metrics/CyclomaticComplexity

      protected def reduce_location(_rule : Int32, rhs_locations : Array(Location?))
        return if rhs_locations.empty?
        Location.merge(rhs_locations.first?, rhs_locations.last?)
      end

      protected def on_error(_token : Token)
      end

      private def recover_from_error(token : Token)
        error_sym = error_symbol

        loop do
          state = @state_stack.last?
          return unless state

          offset = yypact[state]
          if offset != yypact_ninf
            idx = offset + error_sym
            if idx >= 0 && idx <= yylast && yycheck[idx] == error_sym && (action = yytable[idx]) > 0
              return action
            end
          end

          @state_stack.pop
          @value_stack.pop?
          @location_stack.pop?
        end
      end

      private def pop_values(count : Int32)
        return [] of Value if count <= 0
        @value_stack.pop(count)
      end

      private def pop_locations(count : Int32)
        return [] of Location? if count <= 0
        @location_stack.pop(count)
      end

      private def reset_stacks
        @state_stack.clear
        @value_stack.clear
        @location_stack.clear
        @error_status = 0
      end

      private def debug_print(message : String)
        return unless @debug
        STDERR.puts(message)
      end
    end
  end
end
