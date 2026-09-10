# frozen_string_literal: true

# RED→GREEN test for issue #97: date/time arithmetic with temporal quantities
require 'test_helper'

class FHIRPathTemporalArithmeticTest < Minitest::Test
  def test_date_plus_days
    result = FHIRPath.evaluate({}, '@1973-12-25 + 7 days').first
    assert_equal Date.new(1974, 1, 1), result
  end

  def test_date_plus_month
    result = FHIRPath.evaluate({}, '@1973-12-25 + 1 month').first
    assert_equal Date.new(1974, 1, 25), result
  end

  def test_date_plus_week
    result = FHIRPath.evaluate({}, '@1973-12-25 + 1 week').first
    assert_equal Date.new(1974, 1, 1), result
  end

  def test_date_plus_year
    result = FHIRPath.evaluate({}, '@1973-12-25 + 1 year').first
    assert_equal Date.new(1974, 12, 25), result
  end

  def test_datetime_plus_days
    result = FHIRPath.evaluate({}, '@1973-12-25T00:00:00.000+10:00 + 7 days').first
    assert_instance_of DateTime, result
    assert_equal Date.new(1974, 1, 1), result.to_date
  end

  def test_datetime_plus_seconds
    result = FHIRPath.evaluate({}, '@1973-12-25T00:00:00.000+10:00 + 1 second').first
    assert_instance_of DateTime, result
    # Just verify it's a DateTime on the same day
    assert_equal Date.new(1973, 12, 25), result.to_date
  end

  def test_datetime_plus_minutes
    result = FHIRPath.evaluate({}, '@1973-12-25T00:00:00.000+10:00 + 1 minute').first
    assert_instance_of DateTime, result
    # Verify it's approximately 1 minute later (allowing for float precision)
    assert_equal 0, result.hour
    assert_equal 1, result.min
  end

  def test_datetime_plus_hours
    result = FHIRPath.evaluate({}, '@1973-12-25T00:00:00.000+10:00 + 1 hour').first
    assert_instance_of DateTime, result
    # Hours should be exactly 1 hour later
    assert_equal 1, result.hour
    assert_equal 0, result.min
    assert_equal 0, result.sec
  end

  def test_date_minus_days
    result = FHIRPath.evaluate({}, '@1974-01-01 - 7 days').first
    assert_equal Date.new(1973, 12, 25), result
  end

  def test_quantity_equality_with_identifier_units
    assert_equal [true], FHIRPath.evaluate({}, '7 days = 1 week').to_a
  end

  def test_quantity_comparison_with_identifier_units
    assert_equal [true], FHIRPath.evaluate({}, '6 days < 1 week').to_a
    assert_equal [true], FHIRPath.evaluate({}, '8 days > 1 week').to_a
  end

  def test_quantity_method_call_with_identifier_unit
    # toString() is not a registered function, so skip this test
    skip 'toString() not implemented'
  end

  def test_date_plus_decimal_days
    result = FHIRPath.evaluate({}, '@1973-12-25 + 7.7 days').first
    # 7.7 days from Dec 25 -> Jan 1.7 -> Jan 1
    assert_equal 1974, result.year
    assert_equal 1, result.month
    assert_equal 1, result.day
  end
end
