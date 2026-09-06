# frozen_string_literal: true

require 'test_helper'

class FHIRPathTemporalComponentsTest < Minitest::Test
  def test_year_extractor
    result = FHIRPath.evaluate({}, '@2024-01-15.year()')
    assert_equal 1, result.count
    assert_equal 2024, result.first
  end

  def test_month_extractor
    result = FHIRPath.evaluate({}, '@2024-01-15.month()')
    assert_equal 1, result.count
    assert_equal 1, result.first
  end

  def test_day_extractor
    result = FHIRPath.evaluate({}, '@2024-01-15.day()')
    assert_equal 1, result.count
    assert_equal 15, result.first
  end

  def test_hour_extractor
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00Z.hour()')
    assert_equal 1, result.count
    assert_equal 14, result.first
  end

  def test_minute_extractor
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00Z.minute()')
    assert_equal 1, result.count
    assert_equal 30, result.first
  end

  def test_second_extractor
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00Z.second()')
    assert_equal 1, result.count
    assert_equal 0, result.first
  end

  def test_millisecond_extractor
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00.123Z.millisecond()')
    assert_equal 1, result.count
    assert_equal 123, result.first
  end

  def test_timezone_extractor
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00+05:30.timezone()')
    assert_equal 1, result.count
    assert_equal '+05:30', result.first
  end

  def test_timezoneoffset_extractor
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00+05:30.timezoneOffset()')
    assert_equal 1, result.count
    assert_equal 330, result.first
  end
end
