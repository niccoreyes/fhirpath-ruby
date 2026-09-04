# frozen_string_literal: true

module FHIRPath
  # Ordered FHIRPath collection. Empty is represented by an object, not nil.
  class Collection
    include Enumerable

    def self.empty
      new
    end

    def self.from(value)
      return value if value.is_a?(self)
      return empty if value.nil?

      new(value.is_a?(Array) ? value : [value])
    end

    attr_reader :items

    def initialize(items = [])
      @items = flatten_items(Array(items)).freeze
      freeze
    end

    def each(&block)
      return enum_for(:each) unless block

      items.each(&block)
    end

    def empty?
      items.empty?
    end

    def singleton?
      items.length == 1
    end

    def singleton!
      return items.first if singleton?

      raise SingletonError
    end

    def first_item
      items.first
    end

    def count
      items.length
    end

    def to_a
      items.dup
    end

    def +(other)
      Collection.new(items + Collection.from(other).items)
    end

    def map_items(&block)
      Collection.new(map(&block).flat_map { |value| Collection.from(value).items })
    end

    def inspect
      "#<#{self.class} #{items.inspect}>"
    end

    private

    def flatten_items(values)
      values.each_with_object([]) do |value, flattened|
        if value.is_a?(Array)
          flattened.concat(flatten_items(value))
        else
          flattened << value
        end
      end
    end
  end
end
