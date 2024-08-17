# typed: strong
# frozen_string_literal: true

# Represents the priority grouping within a given queue.
class PriorityType < T::Enum
  enums do
    # rubocop:disable Style/MutableConstant
    Default = new
    Long = new
    Dispatch = new
    # rubocop:enable Style/MutableConstant
  end
end
