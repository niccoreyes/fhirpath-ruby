# frozen_string_literal: true

require 'test_helper'

class FHIRPathTemporalLiteralsTest < Minitest::Test
  def test_date_literal_parsing
    result = FHIRPath.evaluate({}, '@2024-01-15')
    assert_equal 1, result.count
    assert_instance_of Date, result.first
    assert_equal Date.new(2024, 1, 15), result.first
  end

  def test_datetime_literal_parsing
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00Z')
    assert_equal 1, result.count
    assert_instance_of DateTime, result.first
    assert_equal DateTime.parse('2024-01-15T14:30:00Z'), result.first
  end

  def test_time_literal_parsing
    result = FHIRPath.evaluate({}, '@T14:30:00')
    assert_equal 1, result.count
    assert_instance_of Time, result.first
    assert_equal 14, result.first.hour
    assert_equal 30, result.first.min
    assert_equal 0, result.first.sec
  end

  def test_datetime_with_timezone_offset
    result = FHIRPath.evaluate({}, '@2024-01-15T14:30:00+05:30')
    assert_equal 1, result.count
    assert_instance_of DateTime, result.first
    assert_equal DateTime.parse('2024-01-15T14:30:00+05:30'), result.first
  end
end
