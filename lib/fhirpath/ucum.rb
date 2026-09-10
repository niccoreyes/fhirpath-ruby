# frozen_string_literal: true

require 'bigdecimal'

require_relative 'ucum_units'

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

    # Base atoms used to render a composed (multiplied) unit.
    BASE_ATOMS = { length: 'm', mass: 'g', volume: 'L', amount: 'mol', time: 's' }.freeze

    module_function

    def validate(unit)
      text = unit.to_s.dup
      definition(text)
      text.freeze
    end

    # Renders a dimension map as a UCUM product of base atoms, e.g.
    # { length: 2 } => "m2". Returns nil when a dimension has no base atom or
    # an exponent outside the supported budget.
    def compose(dimensions)
      return '1' if dimensions.empty?

      parts = dimensions.reject { |_dimension, power| power.zero? }
                        .sort_by { |dimension, _power| dimension.to_s }
                        .map { |dimension, power| compose_atom(dimension, power) }
      return nil if parts.any?(&:nil?)

      parts.join('*')
    end

    def compose_atom(dimension, power)
      atom = BASE_ATOMS[dimension]
      return nil if atom.nil? || power.abs > MAX_EXPONENT

      power == 1 ? atom : "#{atom}#{power}"
    end
    private_class_method :compose_atom

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
      atom, exponent_text = decompose_atom(atom_with_exponent)
      raise ArgumentError, "unsupported Quantity unit: #{original}" unless atom

      exponent = (exponent_text || '1').to_i * exponent_sign
      raise ArgumentError, "Quantity unit exponent exceeds #{MAX_EXPONENT}" if exponent.abs > MAX_EXPONENT

      atom_dimensions, atom_factor = UNIT_ATOMS.fetch(atom)
      [atom_dimensions, atom_factor, exponent]
    end
    private_class_method :atom_definition

    # Splits an atom into its symbol and exponent. UCUM allows the exponent to
    # be written either explicitly (`m^2`) or as a digit suffix (`m2`), and
    # multi-character atoms such as `min` or `mmol` win over the suffix form.
    def decompose_atom(text)
      match = /\A([^^]+)\^(-?\d+)\z/.match(text)
      return [match[1], match[2]] if match && UNIT_ATOMS.key?(match[1])

      return [text, nil] if UNIT_ATOMS.key?(text)

      suffix = /\A(.+?)([+-]?\d+)\z/.match(text)
      return [nil, nil] unless suffix && UNIT_ATOMS.key?(suffix[1])

      [suffix[1], suffix[2]]
    end
    private_class_method :decompose_atom

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
