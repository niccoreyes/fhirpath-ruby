# frozen_string_literal: true

require 'test_helper'

class FHIRPathSingleTest < Minitest::Test
  def test_single_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.single()')
  end

  def test_single_on_singleton_returns_singleton
    assert_equal [1], FHIRPath.evaluate({}, '1.single()').to_a
  end

  def test_single_on_multiple_items_returns_empty
    assert_empty FHIRPath.evaluate({}, '(1 | 2).single()')
  end

  def test_single_on_multiple_items_with_duplicates_returns_empty
    assert_empty FHIRPath.evaluate({}, '(1 | 1 | 2).single()')
  end

  def test_single_on_string_singleton
    assert_equal ['hello'], FHIRPath.evaluate({}, "'hello'.single()").to_a
  end

  def test_single_on_boolean_singleton
    assert_equal [true], FHIRPath.evaluate({}, 'true.single()').to_a
  end

  def test_single_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.single()')
    assert_equal [1, 2, 3], resource['g']
  end
end
