# frozen_string_literal: true

require 'test_helper'

class FHIRPathTemporalComparisonTest < Minitest::Test
  def test_date_comparison
    result = FHIRPath.evaluate({}, '@2024-01-15 < @2024-01-16')
    assert_equal [true], result.to_a
  end

  def test_datetime_comparison
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00Z > @2024-01-15T13:30:00Z')
    assert_equal [true], result.to_a
  end

  def test_time_comparison
    result = FHIRPath.evaluate({}, '@T14:30:00 > @T13:30:00')
    assert_equal [true], result.to_a
  end

  def test_date_equality
    result = FHIRPath.evaluate({}, '@2024-01-15 = @2024-01-15')
    assert_equal [true], result.to_a
  end

  def test_datetime_equality
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00Z = @2024-01-15T14:30:00Z')
    assert_equal [true], result.to_a
  end
end
