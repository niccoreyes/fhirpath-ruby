# frozen_string_literal: true

module FHIRPath
  # A half-open character range in an expression source string.
  class SourceSpan
    attr_reader :offset, :length

    def initialize(offset:, length:)
      raise ArgumentError, 'offset must be non-negative' unless offset.is_a?(Integer) && offset >= 0
      raise ArgumentError, 'length must be non-negative' unless length.is_a?(Integer) && length >= 0

      @offset = offset
      @length = length
      freeze
    end

    def end_offset
      offset + length
    end

    def to_h
      { offset: offset, length: length, end_offset: end_offset }
    end
  end
end
