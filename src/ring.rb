# frozen_string_literal: true

# A fixed-length circular storage.
# When full, the oldest items are removed to make way for new entries.
class Ring
  include Enumerable

  def initialize(size = 100)
    @storage = Array.new(size)
    @position = 0
  end

  def each
    read_position = @position
    @storage.size.times do
      element = @storage[read_position]
      read_position = (read_position + 1) % @storage.size
      next if element.nil?

      yield element
    end
    self
  end

  def <<(element)
    @storage[@position] = element
    @position = (@position + 1) % @storage.size
    self
  end
end
