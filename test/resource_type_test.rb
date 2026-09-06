# frozen_string_literal: true

require 'test_helper'

class FHIRPathResourceTypeTest < Minitest::Test
  def setup
    @observation = {
      'resourceType' => 'Observation',
      'id' => 'obs-1',
      'status' => 'final',
      'code' => { 'coding' => [{ 'system' => 'http://loinc.org', 'code' => '8480-6' }] },
      'valueQuantity' => { 'value' => 5.5, 'unit' => 'mmol/L', 'system' => 'http://unitsofmeasure.org', 'code' => 'mmol/L' }
    }
    @patient = {
      'resourceType' => 'Patient',
      'id' => 'pat-1',
      'name' => [{ 'family' => 'Doe', 'given' => ['John'] }]
    }
  end

  def test_is_resource_returns_true
    resource = @observation
    result = FHIRPath.evaluate(resource, 'true', model: :r4)
    assert_equal [true], result.to_a
  end

  def test_is_with_resource_type
    result = FHIRPath.evaluate(@observation, 'resourceType = \'Observation\'', model: :r4)
    assert_equal [true], result.to_a
  end

  def test_is_with_domainresource_type
    result = FHIRPath.evaluate(@patient, 'resourceType = \'Patient\'', model: :r4)
    assert_equal [true], result.to_a
  end

  def test_oftype_on_resource_types
    # Test that we can filter a collection of resources by type
    bundle = {
      'resourceType' => 'Bundle',
      'entry' => [
        { 'resource' => @observation },
        { 'resource' => @patient }
      ]
    }
    result = FHIRPath.evaluate(bundle, 'entry.resource.ofType(Observation)', model: :r4)
    assert_equal 1, result.count
    assert_equal 'Observation', result.first['resourceType']
  end

  def test_oftype_patient_type
    bundle = {
      'resourceType' => 'Bundle',
      'entry' => [
        { 'resource' => @observation },
        { 'resource' => @patient }
      ]
    }
    result = FHIRPath.evaluate(bundle, 'entry.resource.ofType(Patient)', model: :r4)
    assert_equal 1, result.count
    assert_equal 'Patient', result.first['resourceType']
  end
end
