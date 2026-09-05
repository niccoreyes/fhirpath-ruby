# frozen_string_literal: true

require 'test_helper'

# Issue #13, slice 2: FHIR logical types in `is`/`as` when a ModelProvider is
# active. A ModelProvider resolves the model type of a *resolved* property so
# the evaluator can answer `is Quantity`/`as Quantity` for a choice element
# (e.g. `Observation.valueQuantity`) whose JSON value is an untyped Hash.
class FHIRPathR4PropertyLogicalTypeTest < Minitest::Test
  def test_r4_provider_reports_the_resolved_choice_type
    provider = FHIRPath.model(:r4)
    quantity = { 'resourceType' => 'Observation', 'valueQuantity' => { 'value' => 120, 'unit' => 'mmHg' } }
    string = { 'resourceType' => 'Observation', 'valueString' => 'high' }

    assert_equal 'Quantity', provider.property_logical_type(quantity, 'value')
    assert_equal 'string', provider.property_logical_type(string, 'value')
  end

  def test_r4_provider_reports_nil_when_no_choice_is_present
    provider = FHIRPath.model(:r4)

    assert_nil provider.property_logical_type(
      { 'resourceType' => 'Observation', 'status' => 'final' }, 'value'
    )
  end

  def test_r4_provider_reports_nil_for_non_choice_logical_properties
    provider = FHIRPath.model(:r4)
    resource = { 'resourceType' => 'Observation', 'status' => 'final',
                 'valueQuantity' => { 'value' => 120 } }

    assert_nil provider.property_logical_type(resource, 'status')
    assert_nil provider.property_logical_type({ 'resourceType' => 'Patient' }, 'value')
  end

  def test_base_model_provider_and_plain_model_default_to_no_metadata
    resource = { 'resourceType' => 'Observation', 'valueQuantity' => { 'value' => 120 } }

    assert_nil FHIRPath::ModelProvider.new.property_logical_type(resource, 'value')
    assert_nil FHIRPath::PlainModel.new.property_logical_type(resource, 'value')
  end
end

# Issue #13, slice 2: end-to-end `is`/`as` over FHIR logical types with the R4
# model active. Values stay raw (the JSON Hash for a complex type); the type
# test consults the model type recorded when `Observation.value` resolved a
# choice variant. Semantics mirror the built-in operators: `is` yields a
# singleton Boolean, `as` passes the value through on a match and yields the
# empty collection on a mismatch, and empty input yields empty output.
class FHIRPathR4TypeOperatorTest < Minitest::Test
  QUANTITY = {
    'resourceType' => 'Observation',
    'status' => 'final',
    'valueQuantity' => { 'value' => 120, 'unit' => 'mmHg' }
  }.freeze
  STRING = {
    'resourceType' => 'Observation',
    'status' => 'final',
    'valueString' => 'high'
  }.freeze
  ABSENT = { 'resourceType' => 'Observation', 'status' => 'final' }.freeze

  def test_is_quantity_is_true_for_a_value_quantity_choice
    assert_equal [true], FHIRPath.evaluate(QUANTITY, 'Observation.value is Quantity', model: :r4).to_a
  end

  def test_as_quantity_passes_the_value_quantity_through_unchanged
    assert_equal [QUANTITY['valueQuantity']],
                 FHIRPath.evaluate(QUANTITY, 'Observation.value as Quantity', model: :r4).to_a
  end

  def test_quantity_is_not_a_string_and_cannot_be_cast_to_one
    assert_equal [false], FHIRPath.evaluate(QUANTITY, 'Observation.value is string', model: :r4).to_a
    assert_empty FHIRPath.evaluate(QUANTITY, 'Observation.value as string', model: :r4)
  end

  def test_string_choice_matches_and_cast_passes_through
    assert_equal [true], FHIRPath.evaluate(STRING, 'Observation.value is string', model: :r4).to_a
    assert_equal ['high'], FHIRPath.evaluate(STRING, 'Observation.value as string', model: :r4).to_a
    assert_equal [false], FHIRPath.evaluate(STRING, 'Observation.value is Quantity', model: :r4).to_a
    assert_empty FHIRPath.evaluate(STRING, 'Observation.value as Quantity', model: :r4)
  end

  def test_absent_choice_keeps_the_empty_in_empty_out_rule
    assert_empty FHIRPath.evaluate(ABSENT, 'Observation.value is Quantity', model: :r4)
    assert_empty FHIRPath.evaluate(ABSENT, 'Observation.value as string', model: :r4)
  end

  def test_plain_model_reports_no_model_type_for_choice_values
    assert_empty FHIRPath.evaluate(QUANTITY, 'Observation.value is Quantity')
    assert_empty FHIRPath.evaluate(QUANTITY, 'Observation.value as Quantity')
  end

  def test_symbol_keyed_r4_choice_resolves_its_logical_type
    resource = { resourceType: :Observation, valueQuantity: { value: 90, unit: 'mmHg' } }

    assert_equal [true], FHIRPath.evaluate(resource, 'Observation.value is Quantity', model: :r4).to_a
    assert_equal [{ value: 90, unit: 'mmHg' }],
                 FHIRPath.evaluate(resource, 'Observation.value as Quantity', model: :r4).to_a
  end

  def test_custom_provider_without_type_metadata_keeps_builtin_is_as_behavior
    provider = Class.new(FHIRPath::ModelProvider) do
      def property(element, logical_name)
        element[logical_name] if element.is_a?(Hash)
      end
    end.new
    resource = { 'value' => { 'inner' => 1 } }

    assert_nil provider.property_logical_type(resource, 'value')
    # Without model metadata a structured value is not a known built-in type.
    assert_equal [false], FHIRPath.evaluate(resource, 'value is integer', model: provider).to_a
    assert_empty FHIRPath.evaluate(resource, 'value as integer', model: provider)
  end
end
