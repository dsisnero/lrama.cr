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
      abstract def has_locations? : Bool

      protected def value_stack
        @value_stack
      end

      protected def location_stack
        @location_stack
      end

      private EMPTY_LOCATIONS = [] of Location?

      # ameba:disable Metrics/CyclomaticComplexity
      def parse(lexer : Lexer) : Int32
        reset_stacks
        state = 0
        lookahead = nil.as(Token?)
        repair_tokens = nil.as(Array(Token)?)
        repair_index = 0
        repair_backup = nil.as(Token?)
        parser_action = :push_state
        next_state = nil.as(Int32?)
        rule = nil.as(Int32?)

        loop do
          case parser_action
          when :syntax_error
            token = lookahead || Token.new(error_symbol)
            return 1 unless error_recovery?
            if lookahead && repair_tokens.nil?
              if terms = compute_repair_terms(lookahead.sym)
                repair_tokens = terms.map { |sym| build_repair_token(sym) }
                repair_backup = lookahead
                repair_index = 0
                lookahead = nil
                parser_action = :decide_parser_action
                next
              end
            end
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
              @location_stack << token.location if has_locations?
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

            if lookahead.nil?
              if repair_tokens
                if repair_index < repair_tokens.size
                  lookahead = repair_tokens[repair_index]
                  repair_index += 1
                else
                  lookahead = repair_backup
                  repair_backup = nil
                  repair_tokens = nil
                  repair_index = 0
                end
              end
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
            @location_stack << token.location if has_locations?
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
            stack_base = @value_stack.size - rhs_length
            rhs_locations = has_locations? ? pop_locations(rhs_length) : EMPTY_LOCATIONS
            @state_stack.pop(rhs_length)
            state = @state_stack.last? || raise "state stack is empty after reduce"

            lhs_symbol = yyr1[rule]
            lhs_nterm = lhs_symbol - yyntokens

            value = reduce(rule, @value_stack, rhs_locations)
            location = has_locations? ? reduce_location(rule, rhs_locations) : nil
            @value_stack.pop(rhs_length)

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
            @location_stack << location if has_locations?
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

      protected def build_repair_token(sym : Int32) : Token
        Token.new(sym)
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
          @location_stack.pop? if has_locations?
        end
      end

      private def compute_repair_terms(lookahead_sym : Int32) : Array(Int32)?
        return nil unless error_recovery?

        max_repair = 3
        queue = [] of Tuple(Array(Int32), Array(Int32))
        queue << {@state_stack.dup, [] of Int32}

        until queue.empty?
          state_stack, terms = queue.shift
          state = state_stack.last?
          next unless state

          offset = yypact[state]
          next if offset == yypact_ninf

          limit = yyntokens
          token = 0
          while token < limit
            if token != error_symbol
              idx = offset + token
              if idx >= 0 && idx <= yylast && yycheck[idx] == token
                if terms.size + 1 <= max_repair
                  new_stack = state_stack.dup
                  if process_repairs(new_stack, token)
                    return terms if token == lookahead_sym
                    queue << {new_stack, terms + [token]}
                  end
                end
              end
            end
            token += 1
          end
        end

        nil
      end

      private def process_repairs(state_stack : Array(Int32), token : Int32) : Bool
        yystate = state_stack.last? || return false
        yytoken = token

        loop do
          offset = yypact[yystate]
          if offset == yypact_ninf
            rule = yydefact[yystate]
            return false if rule == 0
            yystate = reduce_state(state_stack, rule)
            return false unless yystate
            next
          end

          idx = offset + yytoken
          if idx < 0 || idx > yylast || yycheck[idx] != yytoken
            rule = yydefact[yystate]
            return false if rule == 0
            yystate = reduce_state(state_stack, rule)
            return false unless yystate
            next
          end

          action = yytable[idx]
          return false if action == yytable_ninf

          if action > 0
            state_stack << action
            return true
          end

          rule = -action
          yystate = reduce_state(state_stack, rule)
          return false unless yystate
        end
      end

      private def reduce_state(state_stack : Array(Int32), rule : Int32) : Int32?
        rhs_length = yyr2[rule]
        rhs_length.times { state_stack.pop? }
        prev_state = state_stack.last?
        return nil unless prev_state

        lhs_symbol = yyr1[rule]
        lhs_nterm = lhs_symbol - yyntokens

        offset = yypgoto[lhs_nterm]
        next_state =
          if offset == yypact_ninf
            yydefgoto[lhs_nterm]
          else
            idx = offset + prev_state
            if idx < 0 || idx > yylast || yycheck[idx] != prev_state
              yydefgoto[lhs_nterm]
            else
              yytable[idx]
            end
          end

        state_stack << next_state
        next_state
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
