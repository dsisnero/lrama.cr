module Lrama
  class Diagram
    # ameba:disable Style/HeredocIndent
    DEFAULT_STYLE = <<-CSS
    * {
      color: #333333;
    }
    svg.railroad-diagram {
      background-color: white;
    }
    svg.railroad-diagram path {
      stroke-width: 3;
      stroke: black;
      fill: rgba(0, 0, 0, 0);
    }
    svg.railroad-diagram text {
      font: bold 14px monospace;
      text-anchor: middle;
    }
    svg.railroad-diagram text.label {
      text-anchor: start;
    }
    svg.railroad-diagram text.comment {
      font: italic 12px monospace;
    }
    svg.railroad-diagram rect {
      stroke-width: 3;
      stroke: #333333;
      fill: hsl(120, 100%, 90%);
    }
    svg.railroad-diagram path {
      stroke: #333333;
    }
    svg.railroad-diagram .terminal rect {
      fill: hsl(190, 100%, 83%);
    }
    svg.railroad-diagram .non-terminal rect {
      fill: hsl(223, 100%, 83%);
    }
    svg.railroad-diagram rect.group-box {
      stroke: gray;
      stroke-dasharray: 10 5;
      fill: none;
    }
    CSS

    # ameba:enable Style/HeredocIndent

    def self.render(io : IO, grammar : Grammar, template_name : String = "diagram/diagram.html")
      new(io: io, grammar: grammar, template_name: template_name).render
    end

    def initialize(@io : IO, @grammar : Grammar, template_name : String = "diagram/diagram.html")
    end

    def render : Nil
      @io << "<!DOCTYPE html>\n"
      @io << "<html>\n"
      @io << "<head>\n"
      @io << "  <title>Lrama syntax diagrams</title>\n"
      @io << "  <style>\n"
      @io << default_style
      @io << "  .diagram-header {\n"
      @io << "    display: inline-block;\n"
      @io << "    font-weight: bold;\n"
      @io << "    font-size: 18px;\n"
      @io << "    margin-bottom: -8px;\n"
      @io << "    text-align: center;\n"
      @io << "  }\n"
      @io << "  .diagram-rule {\n"
      @io << "    display: inline-block;\n"
      @io << "    font: 14px/1.4 monospace;\n"
      @io << "    text-align: left;\n"
      @io << "    margin: 6px 0 24px;\n"
      @io << "  }\n"
      @io << "  svg {\n"
      @io << "    width: 100%;\n"
      @io << "  }\n"
      @io << "  svg.railroad-diagram g.non-terminal text {\n"
      @io << "    cursor: pointer;\n"
      @io << "  }\n"
      @io << "  h2.hover-header {\n"
      @io << "    background-color: #90ee90;\n"
      @io << "  }\n"
      @io << "  svg.railroad-diagram g.non-terminal.hover-g rect {\n"
      @io << "    fill: #eded91;\n"
      @io << "    stroke: 5;\n"
      @io << "  }\n"
      @io << "  svg.railroad-diagram g.terminal.hover-g rect {\n"
      @io << "    fill: #eded91;\n"
      @io << "    stroke: 5;\n"
      @io << "  }\n"
      @io << "  </style>\n"
      @io << "</head>\n"
      @io << "<body align=\"center\">\n"
      @io << diagrams
      @io << "</body>\n"
      @io << "</html>\n"
    end

    def default_style : String
      DEFAULT_STYLE
    end

    def diagrams : String
      String.build do |io|
        @grammar.unique_rule_s_values.each do |s_value|
          rules = @grammar.select_rules_by_s_value(s_value)
          io << "\n<h2 class=\"diagram-header\">#{escape_html(s_value)}</h2>\n"
          io << "<pre class=\"diagram-rule\">"
          rules.each_with_index do |rule, index|
            prefix = index.zero? ? "" : "  | "
            io << "#{prefix}#{escape_html(rule_rhs(rule))}\n"
          end
          io << "</pre>\n"
        end
      end
    end

    private def rule_rhs(rule : Grammar::Rule) : String
      return "%empty" if rule.empty_rule?
      rule.rhs.map(&.display_name).join(" ")
    end

    private def escape_html(text : String) : String
      text
        .gsub("&", "&amp;")
        .gsub("<", "&lt;")
        .gsub(">", "&gt;")
        .gsub("\"", "&quot;")
        .gsub("'", "&#39;")
    end
  end
end
