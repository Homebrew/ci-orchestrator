# typed: strong
# frozen_string_literal: true

# Queues that can be dealt completely separately from each other (typically OS family & arch).
class QueueType < T::Enum
  extend T::Sig

  enums do
    # rubocop:disable Style/MutableConstant
    MacOS_x86_64_Legacy = new
    MacOS_Arm64 = new
    MacOS_x86_64 = new
    # rubocop:enable Style/MutableConstant
  end

  sig { returns(String) }
  def name
    case self
    when MacOS_x86_64_Legacy
      "Legacy x86_64"
    when MacOS_Arm64
      "arm64"
    when MacOS_x86_64
      "New x86_64"
    else
      T.absurd(self)
    end
  end

  sig { returns(Integer) }
  def slots
    case self
    when MacOS_x86_64_Legacy, MacOS_x86_64
      12
    when MacOS_Arm64
      10
    else
      T.absurd(self)
    end
  end
end
