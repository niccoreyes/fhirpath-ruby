# frozen_string_literal: true

require 'test_helper'

# Comparison and equality of temporal values with differing precision return
# an empty collection instead of silently comparing defaulted components
# (FHIRPath 2.0.0, 5.6). Official suite cases: testGreaterThan23/24/25,
# testGreatorOrEqual23/25, testLessThan23/24/25, testLessOrEqual23/25,
# testEquality19, PrecisionYear, PrecisionTimeMinutes,
# PrecisionDateTimeMilliseconds, PrecisionTimeMilliseconds, PrecisionDecimal.
class FHIRPathTemporalPrecisionTest < Minitest::Test
  def evaluate(expression)
    FHIRPath.evaluate({}, expression)
  end

  def test_same_precision_temporal_comparison_still_compares
    assert_equal [true], evaluate('@2018-03 < @2018-04').to_a
    assert_equal [true], evaluate('@2018-03 > @2018-02').to_a
    assert_equal [true], evaluate('@2018-03 = @2018-03').to_a
    assert_equal [false], evaluate('@2018-03 != @2018-03').to_a
    assert_equal [true], evaluate('@T10:30 > @T10:29').to_a
  end

  def test_sub_second_precision_is_compared_numerically
    # `@...T15:30:31.0` is a distinct literal form but not a distinct
    # comparison level: it compares numerically with second precision.
    assert_equal [true], evaluate('@2012-04-15T15:30:31 = @2012-04-15T15:30:31.0').to_a
    assert_equal [false], evaluate('@2012-04-15T15:30:31 = @2012-04-15T15:30:31.1').to_a
    assert_equal [true], evaluate('@2012-04-15T15:30:31 != @2012-04-15T15:30:31.1').to_a
    assert_equal [false], evaluate('@2018-03-01T10:30:00 < @2018-03-01T10:30:00.0').to_a
    assert_equal [false], evaluate('@2018-03-01T10:30:00 > @2018-03-01T10:30:00.0').to_a
    assert_equal [false], evaluate('@T10:30:00 < @T10:30:00.0').to_a
  end

  def test_precision_is_still_reported_for_the_written_form
    assert_equal [17], evaluate('@2012-04-15T15:30:31.0.precision()').to_a
    assert_equal [14], evaluate('@2012-04-15T15:30:31.precision()').to_a
  end

  def test_differing_precision_comparisons_return_empty
    [
      '@2018-03 < @2018-03-01',
      '@2018-03 <= @2018-03-01',
      '@2018-03 > @2018-03-01',
      '@2018-03 >= @2018-03-01',
      '@T10:30 < @T10:30:00',
      '@T10:30 <= @T10:30:00',
      '@T10:30 > @T10:30:00',
      '@T10:30 >= @T10:30:00'
    ].each do |expression|
      assert_empty evaluate(expression), expression
    end
  end

  def test_differing_precision_equality_returns_empty
    assert_empty evaluate('@2018-03 = @2018-03-01')
    assert_empty evaluate('@2012-04-15 = @2012-04-15T10:00:00')
    assert_empty evaluate('@T10:30 = @T10:30:00')
  end

  def test_comparison_of_different_temporal_kinds_is_empty
    assert_empty evaluate('@2012-04-15 < @2012-04-15T10:00:00')
    assert_empty evaluate('@2012-04-15 > @2012-04-15T10:00:00')
  end

  def test_precision_of_temporal_values
    {
      '@2014' => 4,
      '@2014-01' => 6,
      '@2014-01-01' => 8,
      '@2014-01-01T10' => 12,
      '@2014-01-01T10:30' => 12,
      '@2014-01-01T10:30:00' => 14,
      '@2014-01-01T10:30:00.000' => 17,
      '@T10' => 4,
      '@T10:30' => 4,
      '@T10:30:00' => 6,
      '@T10:30:00.000' => 9
    }.each do |expression, expected|
      assert_equal [expected], evaluate("#{expression}.precision()").to_a, expression
    end
  end

  def test_precision_is_empty_for_an_empty_receiver
    assert_empty evaluate('({}).precision()')
  end

  def test_precision_of_a_decimal_is_unsupported
    error = assert_raises(FHIRPath::UnsupportedFeatureError) { evaluate('1.58700.precision()') }

    assert_equal :unsupported_temporal_boundary, error.code
  end

  def test_precision_requires_a_singleton_receiver
    assert_raises(FHIRPath::SingletonError) { evaluate('(@2014 | @2015).precision()') }
  end
end
