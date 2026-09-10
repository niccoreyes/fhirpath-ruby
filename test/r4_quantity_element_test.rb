# frozen_string_literal: true

require 'test_helper'

# FHIR `Quantity` elements are surfaced as FHIRPath Quantity values by the R4
# model provider so they can be compared and combined with quantity literals.
class FHIRPathR4QuantityElementTest < Minitest::Test
  def test_fhir_quantity_element_is_exposed_as_a_fhirpath_quantity
    resource = {
      'resourceType' => 'Observation',
      'status' => 'final',
      'valueQuantity' => { 'value' => 185, 'unit' => 'lbs',
                           'system' => 'http://unitsofmeasure.org', 'code' => '[lb_av]' }
    }

    %w[Observation.value Observation.valueQuantity].each do |expression|
      value = FHIRPath.evaluate(resource, expression, model: :r4).first

      assert_instance_of FHIRPath::Quantity, value, expression
      assert_equal BigDecimal('185'), value.value, expression
      assert_equal '[lb_av]', value.unit, expression
      assert_equal 'http://unitsofmeasure.org', value.system, expression
      assert_equal '[lb_av]', value.code, expression
    end

    assert_equal [true], FHIRPath.evaluate(resource, "Observation.value = 185 '[lb_av]'", model: :r4).to_a
    assert_equal [true], FHIRPath.evaluate(resource, "Observation.value > 100 '[lb_av]'", model: :r4).to_a
    assert_equal [true], FHIRPath.evaluate(resource, 'Observation.value.is(Quantity)', model: :r4).to_a
    assert_equal [BigDecimal('185')], FHIRPath.evaluate(resource, 'Observation.value.value', model: :r4).to_a
    assert_equal ['[lb_av]'], FHIRPath.evaluate(resource, 'Observation.value.unit', model: :r4).to_a
  end

  def test_quantity_element_without_a_supported_unit_keeps_its_raw_form
    resource = {
      'resourceType' => 'Observation',
      'status' => 'final',
      'valueQuantity' => { 'value' => 3, 'unit' => 'furlongs' }
    }

    assert_equal [{ 'value' => 3, 'unit' => 'furlongs' }],
                 FHIRPath.evaluate(resource, 'Observation.value', model: :r4).to_a
    assert_equal [true], FHIRPath.evaluate(resource, 'Observation.value.exists()', model: :r4).to_a
  end

  def test_non_quantity_elements_are_unaffected
    resource = { 'resourceType' => 'Observation', 'status' => 'final', 'valueString' => 'high' }

    assert_equal ['high'], FHIRPath.evaluate(resource, 'Observation.value', model: :r4).to_a
    assert_equal [false], FHIRPath.evaluate(resource, 'Observation.value.is(Quantity)', model: :r4).to_a
  end

  def test_units_of_measure_system_is_preserved_and_can_differ
    resource = {
      'resourceType' => 'Observation',
      'status' => 'final',
      'valueQuantity' => { 'value' => 5.5, 'unit' => 'mmol/L',
                           'system' => 'http://unitsofmeasure.org', 'code' => 'mmol/L' }
    }

    value = FHIRPath.evaluate(resource, 'Observation.value', model: :r4).first

    assert_instance_of FHIRPath::Quantity, value
    assert_equal [true], FHIRPath.evaluate(resource, "Observation.value = 5.5 'mmol/L'", model: :r4).to_a
  end
end
