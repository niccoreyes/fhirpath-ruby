# frozen_string_literal: true

require 'test_helper'

class FHIRPathQuantityEdgeCasesTest < Minitest::Test
  def test_quantity_scalar_multiplication_and_division
    left = FHIRPath.evaluate({}, "5 'mg' * 2").first
    right = FHIRPath.evaluate({}, "2 * 5 'mg'").first
    divided = FHIRPath.evaluate({}, "10 'mg' / 2").first

    assert_equal BigDecimal('10'), left.value
    assert_equal BigDecimal('10'), right.value
    assert_equal BigDecimal('5'), divided.value
    assert_equal 'mg', left.unit
    assert_equal 'mg', right.unit
    assert_equal 'mg', divided.unit
  end

  def test_unary_signs_work_on_quantity_values
    negative = FHIRPath.evaluate({}, "-1 'mg'").first
    positive = FHIRPath.evaluate({}, "+1 'mg'").first

    assert_equal BigDecimal('-1'), negative.value
    assert_equal BigDecimal('1'), positive.value
    assert_equal 'mg', negative.unit
    assert_equal 'mg', positive.unit
  end

  def test_quantity_division_returns_ratio_and_zero_is_empty
    ratio = FHIRPath.evaluate({}, "10 'mg' / 2 'mg'").first

    assert_equal BigDecimal('5'), ratio
    assert_empty FHIRPath.evaluate({}, "10 'mg' / 0 'mg'")
    assert_empty FHIRPath.evaluate({}, "10 'mg' / 2 'm'")
    assert_empty FHIRPath.evaluate({}, "60 'km' / 1 'h'")
  end

  def test_mixed_quantity_scalar_addition_is_empty_in_both_orders
    assert_empty FHIRPath.evaluate({}, "5 'mg' + 2")
    assert_empty FHIRPath.evaluate({}, "2 + 5 'mg'")
  end

  def test_quantity_type_operators_and_oftype
    collection = [FHIRPath::Quantity.new(5, 'mg'), 'hello', 42]
    resource = { items: collection }

    assert_equal 1, FHIRPath.evaluate(resource, 'items.ofType(Quantity)').count
    assert_equal [true], FHIRPath.evaluate({}, "5 'mg' is Quantity").to_a
    assert_equal [FHIRPath.evaluate({}, "5 'mg'").first], FHIRPath.evaluate({}, "5 'mg' as Quantity").to_a
    assert_empty FHIRPath.evaluate({}, "5 'mg' as String")
  end

  def test_quantity_supported_compound_units_are_case_sensitive
    assert_equal [true], FHIRPath.evaluate({}, "1 'mol' = 1000 'mmol'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "1 'kg' = 1000 'g'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "1 'm' = 100 'cm'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "1 'mmol/L' = 1000 'umol/L'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "1 'm^2' = 10000 'cm^2'").to_a
    assert_equal [false], FHIRPath.evaluate({}, "1 'mL' = 1 'ML'").to_a
  end

  def test_wrong_case_units_are_rejected_as_invalid_units
    %w[MG G].each do |unit|
      error = assert_raises(FHIRPath::ParseError) { FHIRPath.evaluate({}, "1 '#{unit}'") }
      assert_equal :invalid_quantity, error.code
    end
  end

  def test_quantity_metadata_does_not_change_unit_equality
    ucum = FHIRPath::Quantity.new(1, 'mg')
    custom = FHIRPath::Quantity.new(1, 'mg', system: 'custom-system', code: 'custom-code')

    assert_equal ucum, custom
  end

  def test_quantity_does_not_freeze_the_caller_unit_string
    unit = +'mg'
    FHIRPath::Quantity.new(1, unit)

    refute unit.frozen?
    unit << 'x'
    assert_equal 'mgx', unit
  end

  def test_quantity_does_not_freeze_caller_metadata_strings
    system = +'custom-system'
    code = +'custom-code'
    FHIRPath::Quantity.new(1, 'mg', system: system, code: code)

    refute system.frozen?
    refute code.frozen?
    system << '-updated'
    code << '-updated'
    assert_equal 'custom-system-updated', system
    assert_equal 'custom-code-updated', code
  end

  def test_quantity_rejects_separator_tainted_units
    %w[g/ g* kg// m*].each do |unit|
      error = assert_raises(FHIRPath::ParseError) { FHIRPath.evaluate({}, "1 '#{unit}'") }
      assert_equal :invalid_quantity, error.code
    end
  end

  def test_quantity_rejects_non_numeric_constructor_values
    assert_raises(ArgumentError) { FHIRPath::Quantity.new('five', 'mg') }
    assert_raises(ArgumentError) { FHIRPath::Quantity.new(1, '') }
  end

  def test_quantity_rejects_excessive_unit_exponents
    error = assert_raises(FHIRPath::ParseError) do
      FHIRPath.evaluate({}, "1 'min^13'")
    end

    assert_equal :invalid_quantity, error.code
  end

  def test_double_quoted_strings_are_a_documented_parser_extension
    assert_equal ['text'], FHIRPath.evaluate({}, '"text"').to_a
  end
end
