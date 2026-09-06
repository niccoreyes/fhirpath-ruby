# frozen_string_literal: true

require 'test_helper'

class FHIRPathTemporalOfTypeTest < Minitest::Test
  def test_oftype_date
    collection = [Date.new(2024, 1, 15), 'hello', 42]
    resource = { items: collection }
    result = FHIRPath.evaluate(resource, 'items.ofType(Date)')
    assert_equal 1, result.count
    assert_equal Date.new(2024, 1, 15), result.first
  end

  def test_oftype_datetime
    collection = [DateTime.parse('2024-01-15T14:30:00Z'), 'hello', 42]
    resource = { items: collection }
    result = FHIRPath.evaluate(resource, 'items.ofType(DateTime)')
    assert_equal 1, result.count
    assert_instance_of DateTime, result.first
  end

  def test_oftype_time
    collection = [Time.new(2024, 1, 15, 14, 30, 0), 'hello', 42]
    resource = { items: collection }
    result = FHIRPath.evaluate(resource, 'items.ofType(Time)')
    assert_equal 1, result.count
    assert_instance_of Time, result.first
  end

  def test_temporal_functions_on_empty_return_empty
    resource = { items: [] }
    result = FHIRPath.evaluate(resource, 'items.year()')
    assert_equal [], result.to_a
  end

  def test_temporal_functions_require_singleton
    resource = { items: [Date.new(2024, 1, 15), Date.new(2024, 1, 16)] }
    assert_raises(FHIRPath::SingletonError) do
      FHIRPath.evaluate(resource, 'items.year()')
    end
  end
end
