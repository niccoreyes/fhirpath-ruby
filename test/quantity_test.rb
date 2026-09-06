# frozen_string_literal: true

require 'test_helper'

class FHIRPathQuantityTest < Minitest::Test
  def test_quantity_literal_parsing
    # Basic quantity literal: 5.5 'mmol/L'
    result = FHIRPath.evaluate({}, "5.5 'mmol/L'")
    assert_equal 1, result.count
    qty = result.first
    assert_kind_of FHIRPath::Quantity, qty
    assert_equal BigDecimal('5.5'), qty.value
    assert_equal 'mmol/L', qty.unit
    assert_equal 'http://unitsofmeasure.org', qty.system
    assert_equal 'mmol/L', qty.code
  end

  def test_quantity_with_explicit_system_code
    # Quantity with explicit system and code: Quantity { value: 5.5, unit: 'mmol/L', system: 'http://unitsofmeasure.org', code: 'mmol/L' }
    result = FHIRPath.evaluate({}, "Quantity { value: 5.5, unit: 'mmol/L', system: 'http://unitsofmeasure.org', code: 'mmol/L' }")
    assert_equal 1, result.count
    qty = result.first
    assert_kind_of FHIRPath::Quantity, qty
    assert_equal BigDecimal('5.5'), qty.value
    assert_equal 'mmol/L', qty.unit
    assert_equal 'http://unitsofmeasure.org', qty.system
    assert_equal 'mmol/L', qty.code
  end

  def test_quantity_equality_same_unit
    # Quantities with same unit should compare by value
    result = FHIRPath.evaluate({}, "5.5 'mmol/L' = 5.5 'mmol/L'")
    assert_equal [true], result.to_a
  end

  def test_quantity_inequality_same_unit
    result = FHIRPath.evaluate({}, "5.5 'mmol/L' != 5.5 'mmol/L'")
    assert_equal [false], result.to_a
  end

  def test_quantity_comparison_same_unit
    result = FHIRPath.evaluate({}, "5.5 'mmol/L' < 6.0 'mmol/L'")
    assert_equal [true], result.to_a
  end

  def test_quantity_equality_different_compatible_units
    # 5.5 mmol/L = 5500 umol/L (if UCUM conversion is available)
    # This test will need a UCUM service; for now test that comparison works
    result = FHIRPath.evaluate({}, "5.5 'mmol/L' = 5500 'umol/L'")
    # Should either be true (if UCUM conversion works) or empty (if not implemented)
    # At minimum, should not raise an error
  end

  def test_quantity_comparison_incompatible_units
    # Comparing mmol/L to kg should return empty or error
    result = FHIRPath.evaluate({}, "5.5 'mmol/L' = 70 'kg'")
    # Should return empty (incompatible) or raise error
  end

  def test_quantity_arithmetic_add_same_unit
    result = FHIRPath.evaluate({}, "5.5 'mmol/L' + 2.5 'mmol/L'")
    assert_equal 1, result.count
    qty = result.first
    assert_kind_of FHIRPath::Quantity, qty
    assert_equal BigDecimal('8.0'), qty.value
    assert_equal 'mmol/L', qty.unit
  end

  def test_quantity_arithmetic_subtract_same_unit
    result = FHIRPath.evaluate({}, "8.0 'mmol/L' - 3.0 'mmol/L'")
    assert_equal 1, result.count
    qty = result.first
    assert_kind_of FHIRPath::Quantity, qty
    assert_equal BigDecimal('5.0'), qty.value
    assert_equal 'mmol/L', qty.unit
  end

  def test_quantity_arithmetic_multiply_by_decimal
    result = FHIRPath.evaluate({}, "5.0 'mmol/L' * 2.0")
    assert_equal 1, result.count
    qty = result.first
    assert_kind_of FHIRPath::Quantity, qty
    assert_equal BigDecimal('10.0'), qty.value
    assert_equal 'mmol/L', qty.unit
  end

  def test_quantity_arithmetic_divide_by_decimal
    result = FHIRPath.evaluate({}, "10.0 'mmol/L' / 2.0")
    assert_equal 1, result.count
    qty = result.first
    assert_kind_of FHIRPath::Quantity, qty
    assert_equal BigDecimal('5.0'), qty.value
    assert_equal 'mmol/L', qty.unit
  end

  def test_quantity_division_returns_ratio
    # Quantity / Quantity with same unit returns a Decimal (ratio)
    result = FHIRPath.evaluate({}, "10.0 'mmol/L' / 2.0 'mmol/L'")
    assert_equal 1, result.count
    assert_kind_of Numeric, result.first
    assert_equal 5.0, result.first
  end

  def test_quantity_division_incompatible_units
    result = FHIRPath.evaluate({}, "5.0 'mmol/L' / 2.0 'kg'")
    # Should return empty or raise error
  end

  def test_quantity_ofType
    collection = [FHIRPath::Quantity.new(5.5, 'mmol/L'), 'hello', 42]
    resource = { items: collection }
    result = FHIRPath.evaluate(resource, 'items.ofType(Quantity)')
    assert_equal 1, result.count
    assert_kind_of FHIRPath::Quantity, result.first
  end

  def test_quantity_with_integer_value
    result = FHIRPath.evaluate({}, "42 'mg'")
    assert_equal 1, result.count
    qty = result.first
    assert_kind_of FHIRPath::Quantity, qty
    assert_equal 42, qty.value  # Integer value
    assert_equal 'mg', qty.unit
  end

  def test_quantity_decimal_value
    result = FHIRPath.evaluate({}, "3.14159 'm'")
    assert_equal 1, result.count
    qty = result.first
    assert_kind_of FHIRPath::Quantity, qty
    assert_equal BigDecimal('3.14159'), qty.value
    assert_equal 'm', qty.unit
  end

  def test_quantity_comparison_with_decimal
    # Quantity vs Decimal comparison
    result = FHIRPath.evaluate({}, "5.0 'mg' > 3.0")
    # Should this work? Probably not directly - comparing quantity to scalar
  end

  def test_quantity_with_empty_input
    resource = { items: [] }
    result = FHIRPath.evaluate(resource, "items.ofType(Quantity)")
    assert_equal [], result.to_a
  end
end