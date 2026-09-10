# frozen_string_literal: true

# RED→GREEN test for issue #97: quantity with identifier units
require 'test_helper'

class FHIRPathTemporalQuantityLiteralTest < Minitest::Test
  def test_quantity_with_identifier_day_unit
    quantity = FHIRPath.evaluate({}, '4 days').first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('4'), quantity.value
    assert_equal 'd', quantity.unit
  end

  def test_quantity_with_identifier_week_unit
    quantity = FHIRPath.evaluate({}, '1 week').first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('1'), quantity.value
    assert_equal 'wk', quantity.unit
  end

  def test_quantity_with_identifier_month_unit
    quantity = FHIRPath.evaluate({}, '1 month').first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('1'), quantity.value
    assert_equal 'mo', quantity.unit
  end

  def test_quantity_with_identifier_year_unit
    quantity = FHIRPath.evaluate({}, '1 year').first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('1'), quantity.value
    assert_equal 'a', quantity.unit
  end

  def test_quantity_with_identifier_second_unit
    quantity = FHIRPath.evaluate({}, '30 seconds').first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('30'), quantity.value
    assert_equal 's', quantity.unit
  end

  def test_quantity_with_identifier_minute_unit
    quantity = FHIRPath.evaluate({}, '5 minutes').first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('5'), quantity.value
    assert_equal 'min', quantity.unit
  end

  def test_quantity_with_identifier_hour_unit
    quantity = FHIRPath.evaluate({}, '2 hours').first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('2'), quantity.value
    assert_equal 'h', quantity.unit
  end

  def test_quantity_with_identifier_millisecond_unit
    quantity = FHIRPath.evaluate({}, '500 millisecond').first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('500'), quantity.value
    assert_equal 'ms', quantity.unit
  end

  def test_plural_units_are_supported
    quantity = FHIRPath.evaluate({}, '7 days').first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('7'), quantity.value
  end

  def test_quoted_unit_still_works
    quantity = FHIRPath.evaluate({}, "1 'cm'").first
    assert_instance_of FHIRPath::Quantity, quantity
    assert_equal BigDecimal('1'), quantity.value
    assert_equal 'cm', quantity.unit
  end

  def test_invalid_temporal_unit_is_rejected
    error = assert_raises(FHIRPath::ParseError) { FHIRPath.parse('1 foo') }
    assert_equal :trailing_input, error.code
  end
end
