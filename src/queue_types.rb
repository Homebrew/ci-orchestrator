# frozen_string_literal: true

# Queues that can be dealt completely separately from each other (typically OS family & arch).
module QueueTypes
  extend Enumerable

  MACOS_X86_64 = 0
  MACOS_ARM64 = 1

  def self.name(type)
    case type
    when MACOS_X86_64
      "x86_64"
    when MACOS_ARM64
      "arm64"
    else
      raise ArgumentError, "Invalid queue type #{type}"
    end
  end

  def self.each(&)
    [MACOS_X86_64, MACOS_ARM64].each(&)
  end
end
