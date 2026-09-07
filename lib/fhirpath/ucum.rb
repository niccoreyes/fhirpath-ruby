# frozen_string_literal: true

require 'bigdecimal'

module FHIRPath
  # Dependency-free, deliberately bounded UCUM support used by Quantity.
  # Unknown atoms are rejected; callers should not interpret this subset as
  # complete UCUM conformance.
  module UCUM
    UnitDefinition = Struct.new(:dimensions, :factor, keyword_init: true) do
      def initialize(**kwargs)
        super
        self.dimensions = dimensions.freeze
        freeze
      end
    end

    MAX_EXPONENT = 12

    UNIT_ATOMS = {
      '1' => [{}, '1'],
      'm' => [{ length: 1 }, '1'],
      'cm' => [{ length: 1 }, '0.01'],
      'mm' => [{ length: 1 }, '0.001'],
      'km' => [{ length: 1 }, '1000'],
      'g' => [{ mass: 1 }, '1'],
      'kg' => [{ mass: 1 }, '1000'],
      'mg' => [{ mass: 1 }, '0.001'],
      'Mg' => [{ mass: 1 }, '1000000'],
      'ug' => [{ mass: 1 }, '0.000001'],
      'ng' => [{ mass: 1 }, '0.000000001'],
      'L' => [{ volume: 1 }, '1'],
      'mL' => [{ volume: 1 }, '0.001'],
      'ML' => [{ volume: 1 }, '1000000'],
      'uL' => [{ volume: 1 }, '0.000001'],
      'mol' => [{ amount: 1 }, '1'],
      'mmol' => [{ amount: 1 }, '0.001'],
      'umol' => [{ amount: 1 }, '0.000001'],
      's' => [{ time: 1 }, '1'],
      'min' => [{ time: 1 }, '60'],
      'h' => [{ time: 1 }, '3600']
    }.freeze

    module_function

    def validate(unit)
      text = unit.to_s.dup
      definition(text)
      text.freeze
    end

    def definition(unit)
      raise ArgumentError, 'Quantity unit must not be blank' if unit.empty?
      return UnitDefinition.new(dimensions: {}, factor: BigDecimal('1')) if unit == '1'

      parts = unit.split('/', -1)
      unless parts.length.between?(1, 2) && parts.none?(&:empty?)
        raise ArgumentError, "unsupported Quantity unit: #{unit}"
      end

      numerator = product_definition(parts.first, unit)
      denominator = build_denominator(parts, unit)
      dimensions = combine_dimensions(numerator.dimensions, denominator.dimensions)
      validate_dimensions!(dimensions)
      UnitDefinition.new(dimensions: dimensions,
                         factor: numerator.factor * denominator.factor)
    end

    def build_denominator(parts, unit)
      return unitless_definition unless parts.length == 2

      product_definition(parts.last, unit, exponent_sign: -1)
    end
    private_class_method :build_denominator

    def validate_dimensions!(dimensions)
      dimensions.each_value do |power|
        next unless power.abs > MAX_EXPONENT

        raise ArgumentError, "Quantity unit exponent exceeds #{MAX_EXPONENT}"
      end
    end
    private_class_method :validate_dimensions!

    def product_definition(product, original, exponent_sign: 1)
      dimensions = {}
      factor = BigDecimal('1')
      product.split('*', -1).each do |atom_with_exponent|
        atom_dimensions, atom_factor, exponent = atom_definition(atom_with_exponent, original, exponent_sign)
        atom_dimensions.each do |dimension, power|
          dimensions[dimension] = dimensions.fetch(dimension, 0) + (power * exponent)
        end
        factor *= BigDecimal(atom_factor)**exponent
      end
      UnitDefinition.new(dimensions: dimensions.reject { |_dimension, power| power.zero? }, factor: factor)
    end
    private_class_method :product_definition

    def atom_definition(atom_with_exponent, original, exponent_sign)
      match = /\A([^\^]+)(?:\^(-?\d+))?\z/.match(atom_with_exponent)
      raise ArgumentError, "unsupported Quantity unit: #{original}" unless match && UNIT_ATOMS.key?(match[1])

      exponent = (match[2] || '1').to_i * exponent_sign
      raise ArgumentError, "Quantity unit exponent exceeds #{MAX_EXPONENT}" if exponent.abs > MAX_EXPONENT

      atom_dimensions, atom_factor = UNIT_ATOMS.fetch(match[1])
      [atom_dimensions, atom_factor, exponent]
    end
    private_class_method :atom_definition

    def unitless_definition
      UnitDefinition.new(dimensions: {}, factor: BigDecimal('1'))
    end
    private_class_method :unitless_definition

    def combine_dimensions(numerator, denominator)
      numerator.merge(denominator) { |_dimension, left, right| left + right }
               .reject { |_dimension, exponent| exponent.zero? }
    end
    private_class_method :combine_dimensions
  end
end
