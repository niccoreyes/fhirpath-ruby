# frozen_string_literal: true

require 'test_helper'

# Tests for keyword-named functions usable after member access (issue #66).
# Keywords like `contains` and `in` are lexed as operators, but after a `.` they
# should be treated as member-invoked function names:
#   Patient.name.contains('John')
class FHIRPathKeywordFunctionTest < Minitest::Test
  def test_keyword_named_functions_after_member_access
    resource = { 'Patient' => { 'name' => %w[John Doe] } }

    assert_equal [true], FHIRPath.evaluate(resource, "Patient.name.contains('John')").to_a
    assert_equal [false], FHIRPath.evaluate(resource, "Patient.name.contains('Bob')").to_a
    assert_equal [true], FHIRPath.evaluate(resource, "'John' in Patient.name").to_a
  end

  def test_keyword_function_rejects_wrong_argument_count
    resource = { 'Patient' => { 'name' => %w[John Doe] } }

    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate(resource, 'Patient.name.contains()')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_keyword_operator_requires_function_call
    # Keyword operators cannot be used as member access without parens
    error = assert_raises(FHIRPath::ParseError) do
      FHIRPath.parse('Patient.in')
    end
    assert_equal :unexpected_token, error.code
  end

  def test_keyword_function_matches_membership_semantics
    resource = { 'Patient' => { 'name' => %w[John Doe] } }

    # `in` as a function: receiver is the singleton value, argument is the collection.
    assert_equal [true], FHIRPath.evaluate(resource, "'John'.in(Patient.name)").to_a
    assert_equal [false], FHIRPath.evaluate(resource, "'Bob'.in(Patient.name)").to_a

    # A string receiver is a singleton collection, so contains() is valid.
    assert_equal [true], FHIRPath.evaluate({}, "'John'.contains('John')").to_a
  end
end
