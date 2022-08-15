# encoding: utf-8
# This file is part of ruby-flores.
# Copyright (C) 2015 Jordan Sissel
# 
require "spec_init"

Counter = Class.new do
  attr_reader :value
  def initialize
    @value = 0
  end

  def incr
    @value += 1
  end

  def decr
    @value -= 1
  end
end

describe Flores::RSpec::Stress do
  subject { Counter.new }
  before do
    expect(subject.value).to(be == 0)
    subject.incr
    expect(subject.value).to(be == 1)
  end
  
  after do
    expect(subject.value).to(be == 1)
    subject.decr
    expect(subject.value).to(be == 0)
  end

  stress_it "should call all before and after hooks" do
    expect(subject.value).to(be == 1)
  end

  describe "level 1" do
    before do
      expect(subject.value).to(be == 1)
      subject.incr
      expect(subject.value).to(be == 2)
    end
    
    after do
      expect(subject.value).to(be == 2)
      subject.decr
      expect(subject.value).to(be == 1)
    end

    stress_it "should call all before and after hooks" do
      expect(subject.value).to(be == 2)
    end

    describe "level 2" do
      before do
        expect(subject.value).to(be == 2)
        subject.incr
        expect(subject.value).to(be == 3)
      end
      
      after do
        expect(subject.value).to(be == 3)
        subject.decr
        expect(subject.value).to(be == 2)
      end

      stress_it "should call all before and after hooks" do
        expect(subject.value).to(be == 3)
      end
    end
  end
end
