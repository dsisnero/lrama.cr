module Lrama
  class Options
    property skeleton : String
    property? locations : Bool
    property? header : Bool
    property header_file : String?
    property report_file : String?
    property outfile : String
    property? error_recovery : Bool
    property grammar_file : String
    property trace_opts : Hash(Symbol, Bool)?
    property report_opts : Hash(Symbol, Bool)?
    property? warnings : Bool
    property y : IO
    property? debug : Bool
    property define : Hash(String, String)
    property? diagram : Bool
    property diagram_file : String
    property profile_opts : Hash(Symbol, Bool)?

    def initialize
      @skeleton = "crystal/parser.ecr"
      @locations = false
      @define = {} of String => String
      @header = false
      @header_file = nil
      @report_file = nil
      @outfile = "y.tab.cr"
      @error_recovery = false
      @grammar_file = ""
      @trace_opts = nil
      @report_opts = nil
      @warnings = false
      @y = STDIN
      @debug = false
      @diagram = false
      @diagram_file = "diagram.html"
      @profile_opts = nil
    end
  end
end
