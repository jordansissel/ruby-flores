# encoding: utf-8
# This file is part of ruby-flores.
# Copyright (C) 2015 Jordan Sissel
# 
require "flores/rspec"
require "flores/random"

RSpec.configure do |config|
  Flores::RSpec.configure(config)
  Kernel.srand config.seed

  # Demonstrate the wonderful Analyze formatter
  config.add_formatter("Flores::RSpec::Formatters::Analyze")
end

describe "a random number" do
  analyze_results

  context "between 0 and 200 inclusive" do
    let(:number) { Flores::Random.number(0..200) }
    stress_it "should be less than 100" do
      expect(number).to(be < 100)
    end
  end
end
