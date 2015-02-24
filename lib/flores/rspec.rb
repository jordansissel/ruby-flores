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
# :nodoc:
require "flores/namespace"

module Flores::RSpec
  DEFAULT_ITERATIONS = 1..5000

  def self.configure(rspec_configuration)
    require "flores/rspec/stress"
    require "flores/rspec/analyze"
    rspec_configuration.extend(Flores::RSpec::Stress)
    rspec_configuration.extend(Flores::RSpec::Analyze)
  end
end
