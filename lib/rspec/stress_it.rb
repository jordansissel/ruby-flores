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
require "rspec/core"

# RSpec helpers for stress testing examples
#
# Setting it up in rspec:
#
#     RSpec.configure do |c|
#       c.extend RSpec::StressIt
#     end
#
# TODO(sissel): Show an example of stress_it and analyze_it
module RSpec::StressIt
  DEFAULT_ITERATIONS = 1..5000

  # Wraps `it` and runs the block many times. Each run has will clear the `let` cache.
  #
  # The intent of this is to allow randomized testing for fuzzing and stress testing
  # of APIs to help find edge cases and weird behavior.
  #
  # The default number of iterations is randomly selected between 1 and 1000 inclusive
  def stress_it(name, options = {}, &block)
    stress__iterations = Randomized.iterations(options.delete(:stress_iterations) || DEFAULT_ITERATIONS)
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
  #     let(:number) { Randomized.number(0..200) }
  #     it "should be less than 100" do
  #       expect(number).to(be < 100)
  #     end
  def stress_it2(name, options = {}, &block)
    stress__iterations = Randomized.iterations(options.delete(:stress_iterations) || DEFAULT_ITERATIONS)
    stress__iterations.each do |i|
      it(name + " [#{i}]", *args) do
        instance_eval(&block)
      end # it ...
    end # .times
  end 

  # Perform analysis on failure scenarios of a given example
  #
  # This will run the given example a random number of times and aggregate the
  # results. If any failures occur, the spec will fail and a report will be
  # given on that test.
  #
  # Example spec:
  #
  #     let(:number) { Randomized.number(0..200) }
  #     fuzz "should be less than 100" do
  #       expect(number).to(be < 100)
  #     end
  #
  # Example report:
  def analyze_it(name, variables, &block) # rubocop:disable Metrics/AbcSize
    it(name) do
      results = Hash.new { |h, k| h[k] = [] }
      Randomized.iterations(DEFAULT_ITERATIONS).each do
        state = Hash[variables.collect { |l| [l, __send__(l)] }]
        begin
          instance_eval(&block)
          results[:success] << [state, nil]
        rescue => e
          results[e.class] << [state, e]
        rescue Exception => e # rubocop:disable Lint/RescueException
          results[e.class] << [state, e]
        end

        # Clear `let` memoizations
        __memoized.clear
      end

      raise StandardError, Analysis.new(results) if results.any? { |k, _| k != :success }
    end
  end # def analyze_it

  # A formatter to show analysis of an `analyze_it` example. 
  class Analysis < StandardError
    def initialize(results)
      @results = results
    end # def initialize

    def total
      @results.reduce(0) { |m, (_, v)| m + v.length }
    end # def total

    def success_count
      if @results.include?(:success)
        @results[:success].length
      else
        0
      end
    end # def success_count

    def percent(count)
      return (count + 0.0) / total
    end # def percent

    def percent_s(count)
      return format("%.2f%%", percent(count) * 100)
    end # def percent_s

    def to_s
      # This method is crazy complex for a formatter. Should refactor this significantly.
      report = ["#{percent_s(success_count)} tests successful of #{total} tests"]
      report += failure_summary if success_count < total
      report.join("\n")
    end # def to_s

    # TODO(sissel): All these report/summary/to_s things are an indication that the
    # report formatting belongs in a separate class.
    def failure_summary
      report = ["Failure analysis:"]
      report += @results.sort_by { |_, v| -v.length }.collect do |group, instances|
        next if group == :success
        error_report(group, instances)
      end.reject(&:nil?).flatten
      report
    end # def failure_summary

    def error_report(error, instances)
      report = error_summary(error, instances)
      report += error_sample_states(error, instances) if instances.size > 1
      report
    end # def error_report

    def error_summary(error, instances)
      sample = instances.sample(1)
      [ 
        "  #{percent_s(instances.length)} -> [#{instances.length}] #{error}",
        "    Sample exception for #{sample.first[0]}",
        sample.first[1].to_s.gsub(/^/, "      ")
      ]
    end # def error_summary

    def error_sample_states(error, instances)
      [ 
        "    Samples causing #{error}:",
        *instances.sample(5).collect { |state, _exception| "      #{state}" }
      ]
    end # def error_sample_states
  end # class Analysis
end # module RSpec::StressIt
