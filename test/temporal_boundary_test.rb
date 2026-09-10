# frozen_string_literal: true

require 'test_helper'

# lowBoundary() / highBoundary() for temporal values (FHIRPath 2.0.0 utility
# functions). Official suite cases: LowBoundaryDateMonth,
# LowBoundaryDateTimeMillisecond1/2/3, LowBoundaryTimeMillisecond,
# HighBoundaryDateMonth, HighBoundaryDateTimeMillisecond1/2/3,
# HighBoundaryTimeMillisecond.
class FHIRPathTemporalBoundaryTest < Minitest::Test
  def evaluate(expression)
    FHIRPath.evaluate({}, expression)
  end

  def first(expression)
    evaluate(expression).first
  end

  def test_low_boundary_of_a_year_precision_date
    value = first('@2014.lowBoundary(6)')

    assert_instance_of FHIRPath::Temporal, value
    assert_equal :date, value.kind
    assert_equal 6, value.precision
    assert_equal Date.new(2014, 1, 1), value.value
  end

  def test_high_boundary_of_a_year_precision_date
    value = first('@2014.highBoundary(6)')

    assert_instance_of FHIRPath::Temporal, value
    assert_equal :date, value.kind
    assert_equal Date.new(2014, 12, 1), value.value
  end

  def test_low_boundary_of_a_minute_precision_time
    value = first('@T10:30.lowBoundary(9)')

    assert_instance_of FHIRPath::Temporal, value
    assert_equal :time, value.kind
    assert_equal 9, value.precision
    assert_equal [10, 30, 0, 0], [value.value.hour, value.value.min, value.value.sec, value.value.usec]
  end

  def test_high_boundary_of_a_minute_precision_time
    value = first('@T10:30.highBoundary(9)')

    assert_equal [10, 30, 59, 999_000],
                 [value.value.hour, value.value.min, value.value.sec, value.value.usec]
  end

  def test_boundaries_of_datetime_values_apply_default_timezone_extremes
    low = first('@2014-01-01T08.lowBoundary(17)')
    high = first('@2014-01-01T08.highBoundary(17)')

    assert_equal DateTime.new(2014, 1, 1, 8, 0, 0, '+14:00'), low.value
    assert_equal DateTime.new(2014, 1, 1, 8, 0, 59.999r, '-12:00'), high.value
  end

  def test_boundary_keeps_an_existing_timezone_offset
    low = first('@2014-01-01T08:05+08:00.lowBoundary(17)')
    high = first('@2014-01-01T08:05-05:00.highBoundary(17)')

    assert_equal DateTime.new(2014, 1, 1, 8, 5, 0, '+08:00'), low.value
    assert_equal DateTime.new(2014, 1, 1, 8, 5, 59.999r, '-05:00'), high.value
  end

  def test_boundary_precision_can_reduce_the_result_precision
    value = first('@2014-01-01T08.lowBoundary(8)')

    assert_equal Date.new(2014, 1, 1), temporal_payload_of(value)
  end

  def test_boundary_defaults_to_the_finest_supported_precision
    assert_equal 17, first('@2014-01-01.lowBoundary()').precision
    assert_equal 9, first('@T10:30:00.highBoundary()').precision
  end

  def test_boundary_results_equal_the_matching_partial_literal
    assert_equal [true], evaluate('@2014.highBoundary(6) = @2014-12').to_a
    assert_equal [true], evaluate('@2014.lowBoundary(6) = @2014-01').to_a
    assert_equal [true], evaluate('@T10:30.lowBoundary(9) = @T10:30:00.000').to_a
    assert_equal [true], evaluate('@T10:30.highBoundary(9) = @T10:30:59.999').to_a
  end

  def test_out_of_range_boundary_precision_returns_empty
    assert_empty evaluate('@2014.lowBoundary(-1)')
    assert_empty evaluate('@2014.lowBoundary(18)')
    assert_empty evaluate('@2014.highBoundary(-1)')
    assert_empty evaluate('@2014.highBoundary(18)')
    assert_empty evaluate('@T10:30.lowBoundary(17)')
  end

  def test_boundary_of_an_empty_receiver_is_empty
    assert_empty evaluate('({}).lowBoundary(6)')
    assert_empty evaluate('({}).highBoundary(6)')
  end

  def test_boundary_on_a_non_temporal_value_is_an_unsupported_feature
    error = assert_raises(FHIRPath::UnsupportedFeatureError) { evaluate('1.587.lowBoundary(2)') }

    assert_equal :unsupported_temporal_boundary, error.code
  end

  def test_boundary_precision_must_be_an_integer
    error = assert_raises(FHIRPath::TypeError) { evaluate("@2014.lowBoundary('6')") }

    assert_equal :expected_integer, error.code
  end

  private

  def temporal_payload_of(value)
    value.is_a?(FHIRPath::Temporal) ? value.value : value
  end
end
