# frozen_string_literal: true

require 'test_helper'

class FHIRPathPrimitiveExtensionsTest < Minitest::Test
  def test_primitive_extension_returns_underlying_container
    # FHIRPath spec: <primitive>._<name> returns the underlying primitive
    # element (the {value, extension} container in JSON form) when the source
    # primitive has a value. This is the "primitive extension accessor".
    resource = {
      'resourceType' => 'Patient',
      'name' => [{
        'family' => {
          'value' => 'Doe',
          'extension' => [{
            'url' => 'http://example.com/names',
            'valueString' => 'secret-alias'
          }]
        }
      }]
    }
    result = FHIRPath.evaluate(resource, 'Patient.name.family._family', model: :r4)
    # Returns the container itself (Hash with value + extension)
    assert_equal 1, result.count
    assert_instance_of Hash, result.first
    assert_equal 'Doe', result.first['value']
    assert_equal 1, result.first['extension'].length
  end

  def test_primitive_extension_only_extension_returns_empty
    # When primitive has only an extension (no `value`), _<name> returns empty
    # per FHIRPath 2.0.0 spec.
    resource = {
      'resourceType' => 'Patient',
      'name' => [{
        'family' => {
          'extension' => [{
            'url' => 'http://example.com/names',
            'valueString' => 'secret-alias'
          }]
        }
      }]
    }
    result = FHIRPath.evaluate(resource, 'Patient.name.family._family', model: :r4)
    assert_equal [], result.to_a
  end

  def test_primitive_extension_collection
    # When invoked on a collection of primitives, each with a value, returns containers
    resource = {
      'resourceType' => 'Patient',
      'name' => [{
        'given' => [
          { 'value' => 'John' },
          { 'value' => 'Jane', 'extension' => [{ 'url' => 'u', 'valueString' => 'ext' }] }
        ]
      }]
    }
    result = FHIRPath.evaluate(resource, 'Patient.name.given._given', model: :r4)
    assert_equal 2, result.count
    assert_equal 'John', result.first['value']
    assert_equal 'Jane', result.to_a[1]['value']
  end

  def test_regular_member_access_still_works
    # Regular .<name> navigation (not underscore-prefixed) returns the same container
    # but is the "value" accessor, not the extension accessor. Both should work.
    resource = { 'value' => 'hello' }
    result = FHIRPath.evaluate(resource, 'value')
    assert_equal 'hello', result.first
  end
end