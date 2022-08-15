# encoding: utf-8
# This file is part of ruby-flores.
# Copyright (C) 2015 Jordan Sissel
# 
require "simplecov"
SimpleCov.start
require "flores/random"
require "flores/rspec"

RSpec.configure do |config|
  Kernel.srand config.seed
  Flores::RSpec.configure(config)
end
