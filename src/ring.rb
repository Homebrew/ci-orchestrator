# typed: strong
# frozen_string_literal: true

# A fixed-length circular storage.
# When full, the oldest items are removed to make way for new entries.
class Ring
  extend T::Sig
  extend T::Generic

  include Enumerable

  Elem = type_member # rubocop:disable Style/MutableConstant

  sig { params(size: Integer).void }
  def initialize(size = 250)
    @storage = T.let(Array.new(size), T::Array[T.nilable(Elem)])
    @position = T.let(0, Integer)
  end

  sig { override.params(_blk: T.proc.params(element: Elem).void).returns(T.self_type) }
  def each(&_blk)
    read_position = @position
    @storage.size.times do
      element = @storage.fetch(read_position)
      read_position = (read_position + 1) % @storage.size
      case element
      when NilClass
        next
      else
        yield element
      end
    end
    self
  end

  sig { params(element: Elem).returns(T.self_type) }
  def <<(element)
    @storage[@position] = element
    @position = (@position + 1) % @storage.size
    self
  end
end
