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

# A collection of methods intended for use in randomized testing.
module Randomized
  # A selection of UTF-8 characters
  #
  # I'd love to generate this, but I don't yet know enough about how unicode
  # blocks are allocated to do that. For now, hardcode a set of possible
  # characters.
  CHARACTERS = [
    # Basic Latin
    *(32..126).map(&:chr),

    # hand-selected CJK Unified Ideographs Extension A
    "㐤", "㐨", "㐻", "㑐",

    # hand-selected Hebrew
    "א", "ב", "ג", "ד", "ה",

    # hand-selected Cyrillic
    "Є", "Б", "Р", "н", "я"
  ]

  # Generates text with random characters of a given length (or within a length range)
  #
  # * The length can be a number or a range `x..y`. If a range, it must be ascending (x < y)
  # * Negative lengths are not permitted and will raise an ArgumentError
  #
  # @param length [Fixnum or Range] the length of text to generate
  # @return [String] the 
  def self.text(length)
    return text_range(length) if length.is_a?(Range)

    raise ArgumentError, "A negative length is not permitted, I received #{length}" if length < 0
    length.times.collect { character }.join
  end # def text

  def self.text_range(range)
    raise ArgumentError, "Requires ascending range, you gave #{range}." if range.end < range.begin
    raise ArgumentError, "A negative range values are not permitted, I received range #{range}" if range.begin < 0
    text(integer(range))
  end

  # Generates a random character (A string of length 1)
  #
  # @return [String]
  def self.character
    return CHARACTERS[integer(0...CHARACTERS.length)]
  end # def character

  # Return a random integer value within a given range.
  #
  # @param range [Range]
  def self.integer(range)
    raise ArgumentError, "Range not given, got #{range.class}: #{range.inspect}" if !range.is_a?(Range)
    rand(range)
  end # def integer

  # Return a random number within a given range.
  #
  # @param range [Range]
  def self.number(range)
    raise ArgumentError, "Range not given, got #{range.class}: #{range.inspect}" if !range.is_a?(Range)
    # Range#size returns the number of elements in the range, not the length of the range.
    # This makes #size return (abs(range.begin - range.end) + 1), and we want the length, so subtract 1.
    rand * (range.size - 1) + range.begin
  end # def number
   
  # Run a block a random number of times.
  #
  # @param range [Fixnum of Range] same meaning as #integer(range)
  def self.iterations(range, &block)
    range = 0..range if range.is_a?(Numeric)
    if block_given?
      integer(range).times(&block)
      nil
    else
      integer(range).times
    end
  end # def iterations
end # module Randomized
