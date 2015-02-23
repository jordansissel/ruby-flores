# This file is part of ruby-flores.
# Copyright (C) 2015 Jordan Sissel
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# encoding: utf-8
require "flores/namespace"
require "flores/rspec"

module Flores::RSpec::Stress
  # Wraps `it` and runs the block many times. Each run has will clear the `let` cache.
  #
  # The intent of this is to allow randomized testing for fuzzing and stress testing
  # of APIs to help find edge cases and weird behavior.
  #
  # The default number of iterations is randomly selected between 1 and 1000 inclusive
  def stress_it(name, options = {}, &block)
    stress__iterations = Flores::Random.iterations(options.delete(:stress_iterations) || Flores::RSpec::DEFAULT_ITERATIONS)
    it(name, options) do
      # Run the block of an example many times
      stress__iterations.each do
        # Run the block within 'it' scope
        instance_eval(&block)

        # clear the internal rspec `let` cache this lets us run a test
        # repeatedly with fresh `let` evaluations.
        # Reference: https://github.com/rspec/rspec-core/blob/5fc29a15b9af9dc1c9815e278caca869c4769767/lib/rspec/core/memoized_helpers.rb#L124-L127
        __memoized.clear
      end
    end # it ...
  end # def stress_it

  # Generate a random number of copies of a given example.
  # The idea is to take 1 `it` and run it N times to help tease out failures.
  # Of course, the teasing requires you have randomized `let` usage, for example:
  #
  #     let(:number) { Flores::Random.number(0..200) }
  #     it "should be less than 100" do
  #       expect(number).to(be < 100)
  #     end
  def stress_it2(name, options = {}, &block)
    stress__iterations = Flores::Random.iterations(options.delete(:stress_iterations) || Flores::RSpec::DEFAULT_ITERATIONS)
    stress__iterations.each do |i|
      it(name + " [#{i}]", *args) do
        instance_eval(&block)
      end # it ...
    end # .times
  end 
end # Flores::RSpec::Stress
