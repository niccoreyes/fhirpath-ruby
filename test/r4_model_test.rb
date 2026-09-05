# frozen_string_literal: true

require 'test_helper'

class FHIRPathR4ModelTest < Minitest::Test
  def test_r4_model_is_selectable_through_public_api
    resource = {
      'resourceType' => 'Observation',
      'valueString' => 'blood pressure'
    }

    assert_instance_of FHIRPath::FHIR::R4::ModelProvider, FHIRPath.model(:r4)
    assert_equal ['blood pressure'], FHIRPath.evaluate(resource, 'Observation.value', model: :r4).to_a
  end

  def test_r4_choice_navigation_accepts_symbol_resource_type
    resources = [
      { resourceType: :Observation, 'valueString' => 'string-key value' },
      { resourceType: :Observation, valueString: 'symbol-key value' }
    ]

    assert_equal ['string-key value'], FHIRPath.evaluate(resources[0], 'Observation.value', model: :r4).to_a
    assert_equal ['symbol-key value'], FHIRPath.evaluate(resources[1], 'Observation.value', model: :r4).to_a
  end

  def test_r4_choice_metadata_describes_observation_value_types
    provider = FHIRPath.model(:r4)

    assert_equal %w[Quantity CodeableConcept string boolean integer Range Ratio SampledData time dateTime Period],
                 provider.choice_types('Observation', 'value')
  end

  def test_observation_value_quantity_is_reached_through_logical_value
    resource = {
      'resourceType' => 'Observation',
      'valueQuantity' => { 'value' => 120, 'unit' => 'mmHg' }
    }

    assert_equal [120], FHIRPath.evaluate(resource, 'Observation.value.value', model: 'R4').to_a
  end

  def test_absent_observation_choice_is_an_empty_collection
    resource = { 'resourceType' => 'Observation', 'status' => 'final' }

    assert_empty FHIRPath.evaluate(resource, 'Observation.value', model: :r4)
  end

  def test_r4_model_does_not_enable_arbitrary_ruby_method_dispatch
    dangerous = Class.new do
      attr_reader :called

      def dangerous
        @called = true
        'side effect'
      end
    end.new

    assert_empty FHIRPath.evaluate(dangerous, 'dangerous', model: :r4)
    refute dangerous.called
  end

  def test_capability_exposes_the_r4_model_release
    capability = FHIRPath::Capability.current

    assert_includes capability.model_releases, 'R4'
    assert_includes capability.capability_set, 'fhir-r4-model'
    assert capability.supports_model?(:r4)
  end

  def test_model_selection_accepts_a_lowercase_configured_release
    capability = FHIRPath::Capability.new(model_releases: ['r4'])
    resource = { 'resourceType' => 'Observation', 'valueString' => 'blood pressure' }

    assert_equal ['blood pressure'],
                 FHIRPath.evaluate(resource, 'Observation.value', model: :r4,
                                                                  capability: capability).to_a
  end

  def test_plain_model_remains_the_default_and_does_not_resolve_choice_keys
    resource = { 'resourceType' => 'Observation', 'valueString' => 'blood pressure' }

    assert_empty FHIRPath.evaluate(resource, 'Observation.value')
  end

  def test_model_selection_honors_a_capability_without_r4
    capability = FHIRPath::Capability.new(model_releases: [])

    error = assert_raises(FHIRPath::UnsupportedFeatureError) do
      FHIRPath.evaluate({}, 'Observation.value', model: :r4, capability: capability)
    end

    assert_equal :unsupported_model_release, error.code
  end
end
