require "./spec_helper"

require "../sample/calc_parser"

private def parse_calc(input : String) : Array(Int32)
  parser = CalcParser.run(IO::Memory.new(input))
  parser.results
end

describe "calc parser" do
  it "parses single numbers" do
    parse_calc("1\n").should eq([1])
  end

  it "respects operator precedence" do
    parse_calc("1+2*3\n").should eq([7])
  end

  it "handles parentheses" do
    parse_calc("(1+2)*3\n").should eq([9])
  end
end
