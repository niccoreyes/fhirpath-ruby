#!/usr/bin/env ruby
# frozen_string_literal: true

# RED→GREEN test for issue #96: .is(Type) and .as(Type) member access
require 'test_helper'

class FHIRPathTypeOperatorMemberAccessTest < Minitest::Test
  RESOURCE = {
    'resourceType' => 'Patient',
    'gender' => 'male',
    'name' => [{ 'use' => 'official', 'given' => %w[Ada Augusta] }]
  }.freeze

  # Issue #96: Parser should accept .is(Type) and .as(Type) after member access
  def test_is_member_access_on_boolean
    assert_equal [true], FHIRPath.evaluate({}, 'true.is(Boolean)').to_a
    assert_equal [false], FHIRPath.evaluate({}, 'true.is(Integer)').to_a
  end

  def test_is_member_access_on_string
    assert_equal [false], FHIRPath.evaluate({}, "'hello'.is(Integer)").to_a
    assert_equal [true], FHIRPath.evaluate({}, "'hello'.is(String)").to_a
  end

  def test_is_member_access_on_quantity
    quantity = FHIRPath.evaluate({}, "5 'mg' is Quantity").first
    assert_equal true, quantity
  end

  def test_is_member_access_chained_with_not
    # true.is(Decimal).not() -> false.not() -> true
    assert_equal [true], FHIRPath.evaluate({}, 'true.is(Decimal).not()').to_a
  end

  def test_as_member_access_on_quantity
    result = FHIRPath.evaluate({}, "5 'mg' as Quantity").first
    assert_instance_of FHIRPath::Quantity, result
    assert_equal BigDecimal('5'), result.value
    assert_equal 'mg', result.unit
  end

  def test_as_member_access_returns_empty_on_type_mismatch
    assert_empty FHIRPath.evaluate({}, "5 'mg' as String")
  end

  def test_as_member_access_on_navigation
    resource = { 'resourceType' => 'Observation', 'valueQuantity' => { 'value' => 100, 'unit' => 'mg' } }
    result = FHIRPath.evaluate(resource, 'Observation.value.as(Quantity)').first
    # The result is a hash when returned from the plain model
    assert_instance_of Hash, result
    assert_equal 100, result['value']
  end

  def test_as_member_access_returns_empty_on_resource_type_mismatch
    assert_equal [], FHIRPath.evaluate(RESOURCE, 'Patient.gender.as(HumanName)').to_a
  end

  def test_is_member_access_with_system_namespace
    skip 'System namespace types not supported in member function form yet'
  end

  def test_as_member_access_with_system_namespace
    skip 'System namespace types not supported in member function form yet'
  end

  def test_binary_is_operator_still_works
    assert_equal [true], FHIRPath.evaluate({}, '1 is Integer').to_a
    assert_equal [false], FHIRPath.evaluate({}, '1 is String').to_a
  end

  def test_binary_as_operator_still_works
    result = FHIRPath.evaluate({}, '1 as Integer').first
    assert_instance_of Integer, result
  end

  def test_is_as_function_requires_single_argument
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, 'true.is(Boolean, Integer)')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_as_as_function_requires_single_argument
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '1.as(Integer, String)')
    end
    assert_equal :invalid_arity, error.code
  end
end
