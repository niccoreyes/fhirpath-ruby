# frozen_string_literal: true

require 'test_helper'

class FHIRPathOfTypeTest < Minitest::Test
  def test_oftype_filters_by_type
    # Given a mixed collection of strings and integers
    collection = [1, 'hello', 2, 'world', 3]
    resource = { items: collection }

    # When filtering for integers
    result = FHIRPath.evaluate(resource, 'items.ofType(Integer)')

    # Then only integers remain
    assert_equal [1, 2, 3], result.to_a
  end

  def test_oftype_returns_empty_when_no_matches
    # Given a collection of strings
    collection = %w[a b c]
    resource = { items: collection }

    # When filtering for integers
    result = FHIRPath.evaluate(resource, 'items.ofType(Integer)')

    # Then empty collection is returned
    assert_equal [], result.to_a
  end

  def test_oftype_requires_single_argument
    # Given any resource
    resource = { dummy: 'data' }

    # When calling ofType with wrong arity
    assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate(resource, 'dummy.ofType()')
    end

    assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate(resource, 'dummy.ofType(Integer, String)')
    end
  end

  def test_oftype_with_decimal
    # Given mixed numeric types
    collection = [1, 2.5, 3, BigDecimal('4.0')]
    resource = { items: collection }

    # When filtering for Decimal (should match BigDecimal and Float per FHIRPath)
    result = FHIRPath.evaluate(resource, 'items.ofType(Decimal)')

    # Then Decimal/Float/BigDecimal items remain
    assert_equal [2.5, BigDecimal('4.0')], result.to_a
  end

  def test_oftype_with_boolean
    collection = [true, 1, 'hello', false]
    resource = { items: collection }

    result = FHIRPath.evaluate(resource, 'items.ofType(Boolean)')

    assert_equal [true, false], result.to_a
  end

  def test_oftype_with_string
    collection = [1, 'hello', 2, 'world']
    resource = { items: collection }

    result = FHIRPath.evaluate(resource, 'items.ofType(String)')

    assert_equal %w[hello world], result.to_a
  end

  def test_oftype_empty_input_returns_empty
    resource = { items: [] }

    result = FHIRPath.evaluate(resource, 'items.ofType(Integer)')

    assert_equal [], result.to_a
  end

  def test_oftype_singleton_returns_singleton
    resource = { value: 42 }

    result = FHIRPath.evaluate(resource, 'value.ofType(Integer)')

    assert_equal [42], result.to_a
  end

  def test_oftype_singleton_wrong_type_returns_empty
    resource = { value: 'hello' }

    result = FHIRPath.evaluate(resource, 'value.ofType(Integer)')

    assert_equal [], result.to_a
  end
end
