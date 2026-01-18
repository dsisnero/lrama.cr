require "./spec_helper"

describe Lrama::Grammar::Counter do
  it "increments and returns previous value" do
    counter = Lrama::Grammar::Counter.new(3)
    counter.increment.should eq 3
    counter.increment.should eq 4
  end
end
