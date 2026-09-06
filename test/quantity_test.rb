# frozen_string_literal: true

require 'test_helper'

class FHIRPathQuantityTest < Minitest::Test
  def test_integer_literal_promotes_to_decimal_quantity
    quantity = FHIRPath.evaluate({}, "42 'mg'").first

    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('42'), quantity.value
    assert_equal 'mg', quantity.unit
    assert_equal 'http://unitsofmeasure.org', quantity.system
    assert_equal 'mg', quantity.code
  end

  def test_decimal_exponent_and_double_quoted_literals
    decimal = FHIRPath.evaluate({}, "3.14159 'm'").first
    exponent = FHIRPath.evaluate({}, "1e3 'mg'").first
    double_quoted = FHIRPath.evaluate({}, '5.5 "mmol/L"').first

    assert_equal BigDecimal('3.14159'), decimal.value
    assert_equal BigDecimal('1000'), exponent.value
    assert_equal BigDecimal('5.5'), double_quoted.value
    assert_equal 'mmol/L', double_quoted.unit
  end

  def test_quantity_constructor_has_explicit_defaults_and_is_immutable
    quantity = FHIRPath::Quantity.new(value: 5.5, unit: 'mg')

    assert_equal BigDecimal('5.5'), quantity.value
    assert_equal 'mg', quantity.unit
    assert_equal 'http://unitsofmeasure.org', quantity.system
    assert_equal 'mg', quantity.code
    assert quantity.frozen?
    assert_raises(FrozenError) { quantity.instance_variable_set(:@unit, 'g') }
  end

  def test_quantity_constructor_accepts_positional_value_and_unit
    quantity = FHIRPath::Quantity.new(5, 'mg', system: 'custom-system', code: 'custom-code')

    assert_equal BigDecimal('5'), quantity.value
    assert_equal 'mg', quantity.unit
    assert_equal 'custom-system', quantity.system
    assert_equal 'custom-code', quantity.code
  end

  def test_blank_or_unterminated_units_are_structured_parse_errors
    blank = assert_raises(FHIRPath::ParseError) { FHIRPath.evaluate({}, "1 ''") }
    unterminated = assert_raises(FHIRPath::ParseError) { FHIRPath.evaluate({}, "1 'mg") }

    assert_equal :invalid_quantity, blank.code
    assert_equal :unterminated_string, unterminated.code
  end

  def test_unsupported_units_are_rejected_instead_of_ignored
    error = assert_raises(FHIRPath::ParseError) { FHIRPath.evaluate({}, "1 'furlong'") }

    assert_equal :invalid_quantity, error.code
    assert_match(/unsupported|invalid/i, error.message)
  end

  def test_same_unit_equality_and_comparison
    assert_equal [true], FHIRPath.evaluate({}, "5 'mg' = 5 'mg'").to_a
    assert_equal [false], FHIRPath.evaluate({}, "5 'mg' != 5 'mg'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "5 'mg' < 6 'mg'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "6 'mg' >= 6 'mg'").to_a
  end

  def test_compatible_units_are_converted_for_equality_and_comparison
    assert_equal [true], FHIRPath.evaluate({}, "1 'g' = 1000 'mg'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "1 'g' > 500 'mg'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "1 'L' = 1000 'mL'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "5.5 'mmol/L' = 5500 'umol/L'").to_a
  end

  def test_units_are_case_sensitive_and_incompatible_comparisons_are_empty
    assert_equal [false], FHIRPath.evaluate({}, "1 'mg' = 1 'Mg'").to_a
    assert_equal [false], FHIRPath.evaluate({}, "1 'mmol/L' = 1 'kg'").to_a
    assert_empty FHIRPath.evaluate({}, "1 'mmol/L' < 1 'kg'")
  end

  def test_addition_and_subtraction_preserve_the_left_unit
    sum = FHIRPath.evaluate({}, "5 'mg' + 2 'mg'").first
    converted_sum = FHIRPath.evaluate({}, "1 'g' + 500 'mg'").first
    difference = FHIRPath.evaluate({}, "8 'mmol/L' - 3 'mmol/L'").first

    assert_equal BigDecimal('7'), sum.value
    assert_equal 'mg', sum.unit
    assert_equal BigDecimal('1.5'), converted_sum.value
    assert_equal 'g', converted_sum.unit
    assert_equal BigDecimal('5'), difference.value
    assert_equal 'mmol/L', difference.unit
  end

  def test_incompatible_quantity_addition_is_empty
    assert_empty FHIRPath.evaluate({}, "1 'mg' + 1 'm'")
    assert_empty FHIRPath.evaluate({}, "1 'mg' - 1 'm'")
  end
end
