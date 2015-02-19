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
require "randomized"
require "rspec/stress_it"

RSpec.configure do |c|
  c.extend RSpec::StressIt
end

describe Randomized do
  describe "#text" do
    context "with no arguments" do
      stress_it "should raise ArgumentError" do
        expect { subject.text }.to(raise_error(ArgumentError))
      end
    end

    context "with 1 length argument" do
      subject { described_class.text(length) }

      context "that is positive" do
        let(:length) { rand(1..1000) }
        stress_it "should give a string with that length" do
          expect(subject).to(be_a(String))
          expect(subject.length).to(eq(length))
        end
      end

      context "that is negative" do
        let(:length) { -1 * rand(1..1000) }
        stress_it "should raise ArgumentError" do
          expect { subject }.to(raise_error(ArgumentError))
        end
      end
    end

    context "with 1 range argument" do
      let(:start)  { rand(1..1000) }
      let(:length) { rand(1..1000) }
      subject { described_class.text(range) }

      context "that is ascending" do
        let(:range) { start..(start + length) }
        stress_it "should give a string within that length range" do
          expect(subject).to(be_a(String))
          expect(range).to(include(subject.length))
        end
      end

      context "that is descending" do
        let(:range) { start..(start - length) }
        stress_it "should raise ArgumentError" do
          expect { subject }.to(raise_error(ArgumentError))
        end
      end
    end
  end

  describe "#character" do
    subject { described_class.character }
    stress_it "returns a string of length 1" do
      expect(subject.length).to(be == 1)
    end
  end

  shared_examples_for "numeric type within expected range" do |type|
    let(:start) { Randomized.integer(-100_000..100_000) }
    let(:length) { Randomized.integer(1..100_000) }
    let(:range) { start..(start + length) }

    stress_it "should be a #{type}" do
      expect(subject).to(be_a(type))
    end

    stress_it "should be within the bounds of the given range" do
      expect(range).to(include(subject))
    end
  end

  describe "#integer" do
    it_behaves_like "numeric type within expected range", Fixnum do
      subject { Randomized.integer(range) }
    end
  end

  describe "#number" do
    it_behaves_like "numeric type within expected range", Float do
      subject { Randomized.number(range) }
    end
  end

  describe "#iterations" do
    let(:start) { Randomized.integer(1..100_000) }
    let(:length) { Randomized.integer(1..100_000) }
    let(:range) { start..(start + length) }
    subject { Randomized.iterations(range) }

    stress_it "should return an Enumerable" do
      expect(subject).to(be_a(Enumerable))
    end

    stress_it "should have a size within the expected range" do
      expect(range).to(include(subject.size))
    end
  end
end 
