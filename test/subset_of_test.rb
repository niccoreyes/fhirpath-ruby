# frozen_string_literal: true

require 'test_helper'

class FHIRPathSubsetOfTest < Minitest::Test
  def test_subset_of_single_item_in_collection
    assert_equal [true], FHIRPath.evaluate({}, '1.subsetOf(1 | 2 | 3)').to_a
  end

  def test_subset_of_single_item_not_in_collection
    assert_equal [false], FHIRPath.evaluate({}, '4.subsetOf(1 | 2 | 3)').to_a
  end

  def test_subset_of_empty_collection_is_true
    assert_equal [true], FHIRPath.evaluate({}, '{}.subsetOf(1 | 2 | 3)').to_a
  end

  def test_subset_of_multiple_items_all_present
    assert_equal [true], FHIRPath.evaluate({}, '(1 | 2).subsetOf(1 | 2 | 3)').to_a
  end

  def test_subset_of_multiple_items_one_missing
    assert_equal [false], FHIRPath.evaluate({}, '(1 | 2 | 4).subsetOf(1 | 2 | 3)').to_a
  end

  def test_subset_of_equal_collections
    assert_equal [true], FHIRPath.evaluate({}, '(1 | 2).subsetOf(1 | 2)').to_a
  end
end
