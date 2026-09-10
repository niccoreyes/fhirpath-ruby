# frozen_string_literal: true

require 'test_helper'

class FHIRPathSupersetOfTest < Minitest::Test
  def test_superset_of_single_item_in_collection
    assert_equal [true], FHIRPath.evaluate({}, '(1 | 2 | 3).supersetOf(1)').to_a
  end

  def test_superset_of_single_item_not_in_collection
    assert_equal [false], FHIRPath.evaluate({}, '(1 | 2 | 3).supersetOf(4)').to_a
  end

  def test_superset_of_empty_collection_is_true
    assert_equal [true], FHIRPath.evaluate({}, '(1 | 2 | 3).supersetOf({})').to_a
  end

  def test_superset_of_multiple_items_all_present
    assert_equal [true], FHIRPath.evaluate({}, '(1 | 2 | 3).supersetOf(1 | 2)').to_a
  end

  def test_superset_of_multiple_items_one_missing
    assert_equal [false], FHIRPath.evaluate({}, '(1 | 2 | 3).supersetOf(1 | 2 | 4)').to_a
  end

  def test_superset_of_equal_collections
    assert_equal [true], FHIRPath.evaluate({}, '(1 | 2).supersetOf(1 | 2)').to_a
  end
end
