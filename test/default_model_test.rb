# frozen_string_literal: true

require 'test_helper'

class FHIRPathDefaultR4ModelTest < Minitest::Test
  def test_omitted_model_defaults_to_r4
    observation = {
      'resourceType' => 'Observation',
      'valueString' => 'blood pressure'
    }

    assert_equal ['blood pressure'], FHIRPath.evaluate(observation, 'Observation.value').to_a
  end

  def test_explicit_model_nil_preserves_plain_model_behavior
    observation = {
      'resourceType' => 'Observation',
      'valueString' => 'blood pressure'
    }

    assert_empty FHIRPath.evaluate(observation, 'Observation.value', model: nil)
  end

  def test_explicit_r4_model_still_works
    observation = {
      'resourceType' => 'Observation',
      'valueString' => 'blood pressure'
    }

    assert_equal ['blood pressure'], FHIRPath.evaluate(observation, 'Observation.value', model: :r4).to_a
  end

  def test_compile_without_model_defaults_to_r4
    expression = FHIRPath.compile('Observation.value')
    observation = { 'resourceType' => 'Observation', 'valueString' => 'test' }

    assert_equal ['test'], expression.evaluate(observation).to_a
  end

  def test_compile_with_explicit_nil_keeps_plain_model
    expression = FHIRPath.compile('Observation.value', model: nil)
    observation = { 'resourceType' => 'Observation', 'valueString' => 'test' }

    assert_empty expression.evaluate(observation).to_a
  end

  def test_evaluate_first_without_model_defaults_to_r4
    observation = {
      'resourceType' => 'Observation',
      'valueString' => 'blood pressure'
    }

    assert_equal 'blood pressure', FHIRPath.evaluate_first(observation, 'Observation.value')
  end

  def test_choice_type_operations_work_without_model
    observation = {
      'resourceType' => 'Observation',
      'valueQuantity' => { 'value' => 120, 'unit' => 'mmHg' }
    }

    assert_equal [true], FHIRPath.evaluate(observation, 'Observation.value is Quantity').to_a
  end

  def test_invalid_model_still_raises_error
    observation = { 'resourceType' => 'Observation' }

    error = assert_raises(ArgumentError) do
      FHIRPath.evaluate(observation, '$this', model: :invalid)
    end

    assert_match(/unknown FHIR model release/, error.message)
  end

  def test_plain_model_explicitly_selected_remains_unaffected
    observation = { 'resourceType' => 'Observation', 'valueString' => 'test' }

    assert_empty FHIRPath.evaluate(observation, 'Observation.value', model: FHIRPath::PlainModel.new)
  end
end
