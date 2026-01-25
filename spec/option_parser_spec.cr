require "./spec_helper"

describe Lrama::OptionParser do
  it "parses options and derives report/header files" do
    File.tempfile("lrama") do |file|
      file.puts("%%")
      file.flush

      output_path = file.path + ".out.c"
      args = [
        "-S", "custom",
        "-t",
        "--locations",
        "-D", "foo=bar",
        "-D", "baz",
        "-H",
        "--output=#{output_path}",
        "--report=states,terms",
        "--trace=time",
        file.path,
      ]

      parser = Lrama::OptionParser.new
      options = parser.parse(args)

      options.skeleton.should eq("custom")
      options.debug?.should be_true
      options.locations?.should be_true
      options.define["foo"].should eq("bar")
      options.define["baz"].should eq("")
      options.header?.should be_true
      options.header_file.should eq(File.dirname(output_path) + "/" + File.basename(output_path, ".*") + ".h")
      options.report_file.should eq(File.dirname(file.path) + "/" + File.basename(file.path, ".*") + ".output")
      report_opts = options.report_opts || raise "Report opts missing"
      trace_opts = options.trace_opts || raise "Trace opts missing"
      report_opts.has_key?(:states).should be_true
      report_opts.has_key?(:terms).should be_true
      trace_opts.has_key?(:time).should be_true
      options.diagram?.should be_false

      options.y.close
    end
  end

  it "adds states report for verbose mode" do
    File.tempfile("lrama") do |file|
      file.puts("%%")
      file.flush

      parser = Lrama::OptionParser.new
      options = parser.parse(["-v", file.path])

      report_opts = options.report_opts || raise "Report opts missing"
      report_opts[:states].should be_true
      options.y.close
    end
  end

  it "accepts an explicit diagram file" do
    File.tempfile("lrama") do |file|
      file.puts("%%")
      file.flush

      parser = Lrama::OptionParser.new
      options = parser.parse(["--diagram=diagram.html", file.path])

      options.diagram?.should be_true
      options.diagram_file.should eq("diagram.html")
      options.y.close
    end
  end
end
