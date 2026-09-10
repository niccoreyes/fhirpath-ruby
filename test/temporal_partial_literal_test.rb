# frozen_string_literal: true

require 'test_helper'

# Partial-precision temporal literals (FHIRPath 2.0.0, 5.6 temporal literals).
# Official suite cases: testLiteralDateYear, testLiteralDateMonth,
# testLiteralDateTimeYear, testLiteralDateTimeMonth, testLiteralTimeHour,
# testLiteralTimeMinute, testDateNotEqualTimeMinute.
class FHIRPathTemporalPartialLiteralTest < Minitest::Test
  def evaluate(expression)
    FHIRPath.evaluate({}, expression)
  end

  def first(expression)
    evaluate(expression).first
  end

  def test_year_precision_date_literal
    value = first('@2014')

    assert_instance_of FHIRPath::Temporal, value
    assert_equal :date, value.kind
    assert_equal 4, value.precision
    assert_equal Date.new(2014, 1, 1), value.value
  end

  def test_month_precision_date_literal
    value = first('@2018-03')

    assert_instance_of FHIRPath::Temporal, value
    assert_equal :date, value.kind
    assert_equal 6, value.precision
    assert_equal Date.new(2018, 3, 1), value.value
  end

  def test_full_date_literal_still_returns_a_plain_date
    value = first('@2015-02-04')

    assert_instance_of Date, value
    assert_equal Date.new(2015, 2, 4), value
  end

  def test_year_precision_datetime_literals
    %w[@2015T @2015-01T @2015-01-01T].each_with_index do |expression, index|
      value = first(expression)

      assert_instance_of FHIRPath::Temporal, value, expression
      assert_equal :datetime, value.kind, expression
      assert_equal [4, 6, 8][index], value.precision, expression
      assert_equal 2015, value.value.year
    end
  end

  def test_month_precision_datetime_literal
    value = first('@2015-02T')

    assert_instance_of FHIRPath::Temporal, value
    assert_equal :datetime, value.kind
    assert_equal 6, value.precision
    assert_equal DateTime.new(2015, 2, 1), value.value
  end

  def test_hour_precision_datetime_literal_is_normalised_to_minutes
    value = first('@2014-01-01T08')

    assert_instance_of FHIRPath::Temporal, value
    assert_equal :datetime, value.kind
    assert_equal 12, value.precision
    assert_equal DateTime.new(2014, 1, 1, 8, 0, 0), value.value
  end

  def test_minute_and_second_precision_datetime_literals
    minute = first('@2014-01-01T08:05')
    second = first('@2014-01-01T08:05:06')

    assert_instance_of FHIRPath::Temporal, minute
    assert_equal 12, minute.precision
    assert_instance_of DateTime, second
    assert_equal DateTime.new(2014, 1, 1, 8, 5, 6), second
  end

  def test_hour_and_minute_precision_time_literals
    hour = first('@T14')
    minute = first('@T14:34')

    assert_instance_of FHIRPath::Temporal, hour
    assert_equal :time, hour.kind
    assert_equal 4, hour.precision
    assert_equal [14, 0, 0], [hour.value.hour, hour.value.min, hour.value.sec]

    assert_instance_of FHIRPath::Temporal, minute
    assert_equal :time, minute.kind
    assert_equal 4, minute.precision
    assert_equal [14, 34, 0], [minute.value.hour, minute.value.min, minute.value.sec]
  end

  def test_second_precision_time_literal_is_a_plain_time
    second = first('@T14:34:28')

    assert_instance_of Time, second
    assert_equal [14, 34, 28, 0], [second.hour, second.min, second.sec, second.usec]
    assert_instance_of Time, first('@T14:34:28Z')
  end

  def test_partial_literal_with_timezone_offset_is_accepted
    value = first('@2018-03-01T08:05+08:00')

    assert_instance_of FHIRPath::Temporal, value
    assert_equal DateTime.new(2018, 3, 1, 8, 5, 0, '+08:00'), value.value
  end

  def test_invalid_temporal_literals_remain_structured_parse_errors
    ['@', '@T', '@2014-1', '@2014-01-1', '@2014-01-01T8'].each do |expression|
      error = assert_raises(FHIRPath::ParseError, expression) { evaluate(expression) }

      assert_equal :invalid_temporal, error.code, expression
    end
  end

  def test_partial_literals_report_their_logical_type
    assert_equal [true], evaluate('@2015.is(Date)').to_a
    assert_equal [true], evaluate('@2015-02.is(Date)').to_a
    assert_equal [true], evaluate('@2015T.is(DateTime)').to_a
    assert_equal [true], evaluate('@2015-02T.is(DateTime)').to_a
    assert_equal [true], evaluate('@T14.is(Time)').to_a
    assert_equal [true], evaluate('@T14:34.is(Time)').to_a
    assert_equal [false], evaluate('@2015.is(DateTime)').to_a
    assert_equal [false], evaluate('@T14.is(Date)').to_a
  end

  def test_date_and_time_values_of_differing_kind_are_indeterminate
    assert_empty evaluate('@1974-12-25 != @T12:14')
    assert_empty evaluate('@1974-12-25 = @T12:14')
  end
end
