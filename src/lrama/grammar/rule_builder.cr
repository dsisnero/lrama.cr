module Lrama
  class Grammar
    class RuleBuilder
      property lhs : Lexer::Token::Base?
      property line : Int32?
      getter rule_counter : Counter
      getter midrule_action_counter : Counter
      getter parameterized_resolver : Grammar::Parameterized::Resolver
      getter lhs_tag : Lexer::Token::Tag?
      getter rhs : Array(Lexer::Token::Base)
      property user_code : Lexer::Token::UserCode?
      property precedence_sym : Grammar::Symbol?
      @replaced_rhs : Array(Lexer::Token::Base)?
      @rules : Array(Grammar::Rule)
      @rule_builders_for_parameterized : Array(RuleBuilder)
      @rule_builders_for_derived_rules : Array(RuleBuilder)
      @parameterized_rules : Array(Grammar::Rule)
      @midrule_action_rules : Array(Grammar::Rule)

      def initialize(
        @rule_counter : Counter,
        @midrule_action_counter : Counter,
        @parameterized_resolver : Grammar::Parameterized::Resolver,
        @position_in_original_rule_rhs : Int32? = nil,
        @lhs_tag : Lexer::Token::Tag? = nil,
        @skip_preprocess_references : Bool = false,
      )
        @lhs = nil
        @rhs = [] of Lexer::Token::Base
        @user_code = nil
        @precedence_sym = nil
        @line = nil
        @rules = [] of Grammar::Rule
        @rule_builders_for_parameterized = [] of RuleBuilder
        @rule_builders_for_derived_rules = [] of RuleBuilder
        @parameterized_rules = [] of Grammar::Rule
        @midrule_action_rules = [] of Grammar::Rule
        @replaced_rhs = nil
      end

      def add_rhs(token : Lexer::Token::Base)
        @line ||= token.line
        flush_user_code
        @rhs << token
      end

      def user_code=(user_code : Lexer::Token::UserCode?)
        @line ||= user_code.try(&.line)
        flush_user_code
        @user_code = user_code
      end

      def precedence_sym=(precedence_sym : Grammar::Symbol?)
        flush_user_code
        @precedence_sym = precedence_sym
      end

      def complete_input
        freeze_rhs
      end

      def setup_rules
        preprocess_references unless @skip_preprocess_references
        process_rhs
        resolve_inline_rules
        build_rules
      end

      def rules
        @parameterized_rules + @midrule_action_rules + @rules
      end

      def has_inline_rules?
        rhs.any? { |token| @parameterized_resolver.find_inline(token) }
      end

      private def freeze_rhs
      end

      private def preprocess_references
        numberize_references
      end

      private def build_rules
        tokens = @replaced_rhs || [] of Lexer::Token::Base
        return if tokens.any? { |token| @parameterized_resolver.find_inline(token) }

        rule = Rule.new(
          id: @rule_counter.increment,
          _lhs: lhs,
          _rhs: tokens,
          lhs_tag: lhs_tag,
          token_code: user_code,
          position_in_original_rule_rhs: @position_in_original_rule_rhs,
          precedence_sym: precedence_sym,
          lineno: line
        )
        @rules = [rule]
        @parameterized_rules = @rule_builders_for_parameterized.flat_map(&.rules)
        @midrule_action_rules = @rule_builders_for_derived_rules.flat_map(&.rules)
        @midrule_action_rules.each(&.original_rule=(rule))
      end

      private def process_rhs
        return if @replaced_rhs

        replaced_rhs = [] of Lexer::Token::Base

        rhs.each_with_index do |token, index|
          case token
          when Lexer::Token::Char
            replaced_rhs << token
          when Lexer::Token::Ident
            replaced_rhs << token
          when Lexer::Token::InstantiateRule
            parameterized_rule = @parameterized_resolver.find_rule(token)
            raise "Unexpected token. #{token}" unless parameterized_rule

            bindings = Grammar::Binding.new(parameterized_rule.parameters, token.args)
            lhs_s_value = bindings.concatenated_args_str(token)
            if created_lhs = @parameterized_resolver.created_lhs(lhs_s_value)
              replaced_rhs << created_lhs
            else
              lhs_token = Lexer::Token::Ident.new(lhs_s_value, location: token.location)
              replaced_rhs << lhs_token
              @parameterized_resolver.created_lhs_list << lhs_token
              parameterized_rule.rhs.each do |rhs|
                rule_builder = RuleBuilder.new(
                  @rule_counter,
                  @midrule_action_counter,
                  @parameterized_resolver,
                  lhs_tag: token.lhs_tag || parameterized_rule.tag
                )
                rule_builder.lhs = lhs_token
                rhs.symbols.each { |sym| rule_builder.add_rhs(bindings.resolve_symbol(sym)) }
                rule_builder.line = line
                rule_builder.precedence_sym = rhs.precedence_sym
                rule_builder.user_code = rhs.resolve_user_code(bindings)
                rule_builder.complete_input
                rule_builder.setup_rules
                @rule_builders_for_parameterized << rule_builder
              end
            end
          when Lexer::Token::UserCode
            prefix = token.referred? ? "@" : "$@"
            tag = token.tag || lhs_tag
            new_token = Lexer::Token::Ident.new("#{prefix}#{@midrule_action_counter.increment}", location: token.location)
            replaced_rhs << new_token

            rule_builder = RuleBuilder.new(
              @rule_counter,
              @midrule_action_counter,
              @parameterized_resolver,
              index,
              lhs_tag: tag,
              skip_preprocess_references: true
            )
            rule_builder.lhs = new_token
            rule_builder.user_code = token
            rule_builder.complete_input
            rule_builder.setup_rules

            @rule_builders_for_derived_rules << rule_builder
          when Lexer::Token::Empty
            # No-op
          else
            raise "Unexpected token. #{token}"
          end
        end

        @replaced_rhs = replaced_rhs
      end

      private def resolve_inline_rules
        while @rule_builders_for_parameterized.any?(&.has_inline_rules?)
          @rule_builders_for_parameterized = @rule_builders_for_parameterized.flat_map do |rule_builder|
            if rule_builder.has_inline_rules?
              inlined_builders = Inline::Resolver.new(rule_builder).resolve
              inlined_builders.each(&.setup_rules)
              inlined_builders
            else
              [rule_builder]
            end
          end
        end
      end

      private def numberize_references
        (rhs + [user_code]).compact.each_with_index(1) do |token, index|
          next unless token.is_a?(Lexer::Token::UserCode)

          token.references.each do |ref|
            ref_name = ref.name
            if ref_name
              if ref_name == "$"
                ref.name = "$"
              else
                candidates = ([lhs] + rhs).each_with_index.select do |candidate, _|
                  candidate && candidate.referred_by?(ref_name)
                end

                if candidates.size >= 2
                  token.invalid_ref(ref, "Referring symbol `#{ref_name}` is duplicated.")
                end

                unless referring_symbol = candidates.first
                  token.invalid_ref(ref, "Referring symbol `#{ref_name}` is not found.")
                end

                if referring_symbol[1] == 0
                  ref.name = "$"
                else
                  ref.number = referring_symbol[1]
                end
              end
            end

            ref.index = ref.number if ref.number
            next if ref.type == :at

            if ref_index = ref.index
              token.invalid_ref(ref, "Can not refer following component. #{ref.index} >= #{index}.") if ref_index >= index
              rhs[ref_index - 1].referred = true
            end
          end
        end
      end

      private def flush_user_code
        if code = @user_code
          @rhs << code
          @user_code = nil
        end
      end
    end
  end
end
