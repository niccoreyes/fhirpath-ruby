# frozen_string_literal: true

require 'test_helper'

class FHIRPathR4ExtendedChoiceTest < Minitest::Test
  def test_medication_medication_choice
    medication = {
      'resourceType' => 'Medication',
      'medicationCodeableConcept' => { 'coding' => [{ 'system' => 'http://example.org', 'code' => '123' }] }
    }
    result = FHIRPath.evaluate(medication, 'medication', model: :r4)
    assert_equal 1, result.count
    assert_equal 'CodeableConcept', result.types.first
  end

  def test_medication_medication_reference
    medication = {
      'resourceType' => 'Medication',
      'medicationReference' => { 'reference' => 'Medication/123' }
    }
    result = FHIRPath.evaluate(medication, 'medication', model: :r4)
    assert_equal 1, result.count
    assert_equal 'Reference', result.types.first
  end

  def test_condition_clinical_status
    condition = {
      'resourceType' => 'Condition',
      'clinicalStatusCodeableConcept' => { 'coding' => [{ 'system' => 'http://terminology.hl7.org/CodeSystem/condition-clinical', 'code' => 'active' }] }
    }
    result = FHIRPath.evaluate(condition, 'clinicalStatus', model: :r4)
    assert_equal 1, result.count
    assert_equal 'CodeableConcept', result.types.first
  end

  def test_condition_verification_status
    condition = {
      'resourceType' => 'Condition',
      'verificationStatusCodeableConcept' => { 'coding' => [{ 'system' => 'http://terminology.hl7.org/CodeSystem/condition-ver-status', 'code' => 'confirmed' }] }
    }
    result = FHIRPath.evaluate(condition, 'verificationStatus', model: :r4)
    assert_equal 1, result.count
    assert_equal 'CodeableConcept', result.types.first
  end

  def test_procedure_outcome
    procedure = {
      'resourceType' => 'Procedure',
      'outcomeCodeableConcept' => { 'coding' => [{ 'system' => 'http://example.org', 'code' => 'complete' }] }
    }
    result = FHIRPath.evaluate(procedure, 'outcome', model: :r4)
    assert_equal 1, result.count
    assert_equal 'CodeableConcept', result.types.first
  end

  def test_procedure_indication
    procedure = {
      'resourceType' => 'Procedure',
      'indicationReference' => { 'reference' => 'Condition/123' }
    }
    result = FHIRPath.evaluate(procedure, 'indication', model: :r4)
    assert_equal 1, result.count
    assert_equal 'Reference', result.types.first
  end

  def test_diagnostic_report_category
    diag = {
      'resourceType' => 'DiagnosticReport',
      'categoryCodeableConcept' => { 'coding' => [{ 'system' => 'http://example.org', 'code' => 'LAB' }] }
    }
    result = FHIRPath.evaluate(diag, 'category', model: :r4)
    assert_equal 1, result.count
    assert_equal 'CodeableConcept', result.types.first
  end

  def test_diagnostic_report_code
    diag = {
      'resourceType' => 'DiagnosticReport',
      'codeCodeableConcept' => { 'coding' => [{ 'system' => 'http://example.org', 'code' => '12345' }] }
    }
    result = FHIRPath.evaluate(diag, 'code', model: :r4)
    assert_equal 1, result.count
    assert_equal 'CodeableConcept', result.types.first
  end

  def test_observation_value_choice_still_works
    observation = {
      'resourceType' => 'Observation',
      'valueQuantity' => { 'value' => 5.5, 'unit' => 'mmol/L' }
    }
    result = FHIRPath.evaluate(observation, 'value', model: :r4)
    assert_equal 1, result.count
    assert_equal 'Quantity', result.types.first
  end
end
