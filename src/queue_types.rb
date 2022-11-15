# frozen_string_literal: true

# Queues that can be dealt completely separately from each other (typically OS family & arch).
module QueueTypes
  extend Enumerable

  MACOS_X86_64_LEGACY = 0
  MACOS_ARM64 = 1
  MACOS_X86_64 = 2

  def self.name(type)
    case type
    when MACOS_X86_64_LEGACY
      "Legacy x86_64"
    when MACOS_ARM64
      "arm64"
    when MACOS_X86_64
      "New x86_64"
    else
      raise ArgumentError, "Invalid queue type #{type}"
    end
  end

  def self.slots(type)
    case type
    when MACOS_X86_64_LEGACY
      12
    when MACOS_ARM64,
         MACOS_X86_64
      6
    else
      raise ArgumentError, "Invalid queue type #{type}"
    end
  end

  def self.each(&)
    [MACOS_X86_64_LEGACY, MACOS_ARM64, MACOS_X86_64].each(&)
  end
end
