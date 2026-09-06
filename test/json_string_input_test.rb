# frozen_string_literal: true

require 'test_helper'
require 'json'

# Issue #56: raw JSON document strings are accepted directly by the public
# evaluate boundaries without a separate JSON.parse step.
class JSONStringInputTest < Minitest::Test
  PATIENT = <<~JSON
    {
      "resourceType": "Patient",
      "name": [{ "use": "usual", "family": "Lovelace", "given": ["Ada"] }]
    }
  JSON
  EXPRESSION = "Patient.name.where(use='usual').given.first()"

  def test_object_json_string_is_parsed_like_the_equivalent_hash
    assert_equal ['Ada'], FHIRPath.evaluate(PATIENT, EXPRESSION).to_a
  end

  def test_object_json_string_with_surrounding_whitespace_is_parsed
    padded = " \n\t #{PATIENT} \r\n "
    assert_equal ['Ada'], FHIRPath.evaluate(padded, EXPRESSION).to_a
  end

  def test_object_json_string_with_utf8_bom_is_parsed
    bom_prefixed = "\uFEFF#{PATIENT}"
    assert_equal ['Ada'], FHIRPath.evaluate(bom_prefixed, EXPRESSION).to_a
  end

  def test_ascii8bit_utf8_json_body_with_bom_is_parsed
    binary_body = "\xEF\xBB\xBF#{PATIENT}".b
    assert_equal ['Ada'], FHIRPath.evaluate(binary_body, EXPRESSION).to_a
  end

  def test_array_json_string_becomes_an_array_root
    assert_equal [3], FHIRPath.evaluate('[1, 2, 3]', 'count()').to_a
    assert_equal [3], FHIRPath.evaluate("\n  [1, 2, 3]\t", 'count()').to_a
  end

  def test_json_string_works_with_the_r4_model_adapter
    assert_equal ['Lovelace'], FHIRPath.evaluate(PATIENT, 'Patient.name.family', model: :r4).to_a
  end

  def test_compiled_expression_accepts_json_strings_at_the_same_boundary
    program = FHIRPath.compile(EXPRESSION)

    assert_equal ['Ada'], program.evaluate(PATIENT).to_a
    assert_equal ['Ada'], program.call(PATIENT).to_a
  end

  def test_evaluate_first_accepts_json_strings
    assert_equal 'Ada', FHIRPath.evaluate_first(PATIENT, EXPRESSION)
  end

  def test_malformed_object_json_raises_a_structured_public_error
    error = assert_raises(FHIRPath::JSONInputError) do
      FHIRPath.evaluate('{ "resourceType": "Patient", name: }', EXPRESSION)
    end

    assert_kind_of FHIRPath::Error, error
    assert_equal :invalid_json, error.code
    assert_match(/not valid JSON/, error.message)
    assert_equal :invalid_json, error.to_h[:code]
    assert_match(/not valid JSON/, error.to_h[:message])
    assert_equal EXPRESSION, error.to_h[:expression]
    assert_instance_of JSON::ParserError, error.original_cause
  end

  def test_truncated_and_empty_object_json_are_rejected_clearly
    assert_raises(FHIRPath::JSONInputError) { FHIRPath.evaluate('[1, 2', '$this') }
    assert_raises(FHIRPath::JSONInputError) { FHIRPath.evaluate('{', '$this') }
  end

  def test_deeply_nested_json_is_reported_as_invalid_json
    error = assert_raises(FHIRPath::JSONInputError) do
      FHIRPath.evaluate("#{'[' * 200}#{']' * 200}", '$this')
    end

    assert_equal :invalid_json, error.code
    assert_kind_of JSON::NestingError, error.original_cause
  end

  def test_malformed_json_error_does_not_echo_document_contents
    error = assert_raises(FHIRPath::JSONInputError) do
      FHIRPath.evaluate('{ HIDDEN-SECRET: }', '$this')
    end

    refute_includes error.message, 'HIDDEN-SECRET'
    refute_includes error.to_h[:message], 'HIDDEN-SECRET'
  end
end
