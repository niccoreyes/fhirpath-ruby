# frozen_string_literal: true

require 'test_helper'

class FHIRPathTemporalNowTest < Minitest::Test
  def test_today_returns_current_date
    result = FHIRPath.evaluate({}, 'today()')
    assert_equal 1, result.count
    assert_instance_of Date, result.first
    assert_equal Date.today, result.first
  end

  def test_now_returns_current_datetime
    result = FHIRPath.evaluate({}, 'now()')
    assert_equal 1, result.count
    assert_instance_of DateTime, result.first
    assert_in_delta DateTime.now.strftime('%s').to_f, result.first.strftime('%s').to_f, 2
  end

  def test_time_returns_current_time
    result = FHIRPath.evaluate({}, 'time()')
    assert_equal 1, result.count
    assert_instance_of Time, result.first
    assert_in_delta Time.now.to_f, result.first.to_f, 2
  end
end
