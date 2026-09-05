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

    attr_reader :items, :types

    def initialize(items = [], types: nil)
      @items = flatten_items(Array(items)).freeze
      @types = validate_types(types, @items.length)
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

    # Optional positional model-type metadata parallel to +items+ (entries are
    # logical type names or nil). Without metadata the collection behaves
    # exactly as before; item values are never wrapped or altered.
    def validate_types(types, length)
      return nil if types.nil?

      raise ArgumentError, 'types must match the number of items' unless types.length == length

      types.freeze
    end

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
