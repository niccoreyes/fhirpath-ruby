# frozen_string_literal: true

require 'test_helper'
require 'json'

class JSONStringInputEdgeCasesTest < Minitest::Test
  PATIENT = <<~JSON
    {
      "resourceType": "Patient",
      "name": [{ "use": "usual", "family": "Lovelace", "given": ["Ada"] }]
    }
  JSON
  EXPRESSION = "Patient.name.where(use='usual').given.first()"

  def test_strings_that_do_not_look_like_json_objects_or_arrays_stay_strings
    ['Ada', 'null', 'true', '123', '"Ada"', '', 'Some plain text'].each do |text|
      assert_equal [text], FHIRPath.evaluate(text, '$this').to_a, "input #{text.inspect}"
    end
  end

  def test_json_null_and_scalar_text_follow_existing_string_collection_semantics
    # Detection is deliberately limited to documents that open with `{` or `[`
    # (after whitespace), so JSON scalar text such as "null" keeps its
    # pre-existing meaning: a singleton FHIRPath string, not an empty value.
    assert_equal ['null'], FHIRPath.evaluate('null', '$this').to_a
    assert_equal ['123'], FHIRPath.evaluate('123', '$this').to_a
    assert_equal ['   '], FHIRPath.evaluate('   ', '$this').to_a
  end

  def test_string_keyed_hash_inputs_keep_working_without_json_parsing
    resource = { 'items' => [{ 'id' => 1 }, { 'id' => 2 }] }
    assert_equal [1, 2], FHIRPath.evaluate(resource, 'items.id').to_a
    assert_equal ['Ada'], FHIRPath.evaluate(
      { 'resourceType' => 'Patient', 'name' => [{ 'use' => 'usual', 'family' => 'Lovelace', 'given' => ['Ada'] }] },
      EXPRESSION
    ).to_a
  end

  def test_symbol_keyed_hash_inputs_remain_supported
    patient = {
      resourceType: 'Patient',
      name: [{ use: 'usual', family: 'Lovelace', given: ['Ada'] }]
    }
    assert_equal ['Lovelace'], FHIRPath.evaluate(patient, 'Patient.name.family').to_a
  end

  def test_hash_and_array_inputs_are_used_directly_without_parsing_or_mutation
    marker = Object.new
    resource = { 'items' => [1, 2, 3], 'marker' => marker }

    assert_equal [6], FHIRPath.evaluate(resource, 'items.sum()').to_a
    assert_equal [3], FHIRPath.evaluate([1, 2, 3], 'count()').to_a
    # Values that could never survive JSON serialization prove the Hash itself
    # is never routed through a JSON parser, and the caller's object is intact.
    assert_same marker, resource['marker']
    assert_equal [1, 2, 3], resource['items']
  end

  def test_json_string_input_is_not_mutated_by_evaluation
    original = PATIENT.dup
    FHIRPath.evaluate(PATIENT, EXPRESSION)

    assert_equal original, PATIENT
  end

  def test_invalid_binary_document_strings_raise_structured_errors
    ["{\xFF}".b, "{\"name\":\"\xC3(\"}".b].each do |binary|
      error = assert_raises(FHIRPath::JSONInputError) { FHIRPath.evaluate(binary, '$this') }
      assert_equal :invalid_json, error.code
    end
  end

  def test_non_ascii_compatible_json_encodings_are_normalized
    %w[UTF-16LE UTF-16BE UTF-32LE UTF-32BE].each do |encoding|
      encoded = PATIENT.encode(encoding)

      assert_equal ['Ada'], FHIRPath.evaluate(encoded, EXPRESSION).to_a, encoding
    end
  end

  def test_malformed_non_ascii_compatible_json_is_a_structured_error
    %w[UTF-16LE UTF-16BE UTF-32LE UTF-32BE].each do |encoding|
      error = assert_raises(FHIRPath::JSONInputError) do
        FHIRPath.evaluate('{"resourceType":'.encode(encoding), '$this')
      end

      assert_equal :invalid_json, error.code
    end
  end

  def test_invalid_binary_non_document_strings_keep_legacy_string_semantics
    binary = "\xFFpayload".b

    result = FHIRPath.evaluate(binary, '$this')

    assert_equal [binary], result.to_a
    assert_same binary, result.first
  end
end
