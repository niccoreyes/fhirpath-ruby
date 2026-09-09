# frozen_string_literal: true

require 'test_helper'
require 'fhirpath/vector_runner'
require 'fileutils'
require 'json'
require 'tmpdir'
require 'tempfile'

class FHIRPathVectorRunnerConformanceSemanticsTest < Minitest::Test
  def test_syntax_invalid_case_passes_when_parse_error_raised
    # When error is just a class without code, any instance of that class passes
    vectors = [
      {
        'id' => 'syntax-test', 'expression' => '|||bad|||', 'resource' => {},
        'error' => { 'class' => 'FHIRPath::ParseError' }
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'pass', result['classification'], 'syntax error should pass when ParseError is expected'
    end
  end

  def test_execution_invalid_case_passes_when_evaluation_error_raised
    # unknown() raises UnknownFunctionError which is a subclass of Error
    vectors = [
      {
        'id' => 'execution-test', 'expression' => 'unknown()', 'resource' => {},
        'error' => { 'class' => 'FHIRPath::Error' }
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'pass', result['classification'], 'evaluation error should pass when generic Error is expected'
    end
  end

  def test_execution_invalid_case_fails_when_parse_error_raised_instead
    # ParseError is a subclass of Error, so this should still pass
    vectors = [
      {
        'id' => 'wrong-error-type', 'expression' => '|||bad|||', 'resource' => {},
        'error' => { 'class' => 'FHIRPath::Error' }
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      # ParseError is a subclass of Error, so it matches
      assert_equal 'pass', result['classification']
    end
  end

  def test_generic_error_true_passes_any_evaluation_error
    vectors = [
      {
        'id' => 'generic-error-1', 'expression' => 'unknown()', 'resource' => {},
        'error' => true
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)

      assert_equal 'pass', report[:cases].first['classification']
    end
  end

  def test_generic_error_true_fails_when_evaluation_succeeds
    vectors = [
      {
        'id' => 'expected-error-but-passed', 'expression' => '1 + 1', 'resource' => {},
        'error' => true
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'defect', result['classification'], 'should be defect when error expected but evaluation succeeds'
    end
  end

  def test_unrelated_exception_is_defect_even_when_error_expected
    vectors = [
      {
        'id' => 'wrong-exception', 'expression' => 'anything', 'resource' => {},
        'error' => { 'class' => 'FHIRPath::UnsupportedFeatureError', 'code' => 'unsupported_function' }
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(
        file.path,
        evaluator: ->(_vector) { raise StandardError, 'boom' }
      )
      result = report[:cases].first

      assert_equal 'defect', result['classification']
      assert_equal 'StandardError', result['actual_error']['class']
    end
  end

  def test_typed_output_boolean_preserves_case
    vectors = [
      {
        'id' => 'typed-bool', 'expression' => 'true', 'resource' => {},
        'expected' => [true]
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'pass', result['classification']
      assert_equal [true], result['actual']
    end
  end

  def test_typed_output_integer_preserves_value
    vectors = [
      {
        'id' => 'typed-int', 'expression' => '1 + 2', 'resource' => {},
        'expected' => [3]
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'pass', result['classification']
      assert_equal [3], result['actual']
    end
  end

  def test_empty_output_is_valid_when_expected_empty
    vectors = [
      {
        'id' => 'empty-output', 'expression' => '{}.name', 'resource' => {},
        'expected' => []
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'pass', result['classification']
      assert_equal [], result['actual']
    end
  end

  def test_multiple_outputs_preserved_in_order
    vectors = [
      {
        'id' => 'multi-output', 'expression' => '(1 | 2 | 3)', 'resource' => {},
        'expected' => [1, 2, 3]
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'pass', result['classification']
      assert_equal [1, 2, 3], result['actual']
    end
  end

  def test_decimal_output_preserved_as_string
    # Decimal outputs from XML are preserved as strings for precision
    vectors = [
      {
        'id' => 'decimal-output', 'expression' => '1.0', 'resource' => {},
        'expected' => ['1.0']
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'defect', result['classification'], "decimal string doesn't match float evaluation"
    end
  end

  def test_string_whitespace_preserved
    vectors = [
      {
        'id' => 'whitespace-string', 'expression' => "'  hello  world  '", 'resource' => {},
        'expected' => ['  hello  world  ']
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'pass', result['classification']
      assert_equal ['  hello  world  '], result['actual']
    end
  end

  def test_report_fields_distinguish_error_types
    vectors = [
      {
        'id' => 'parse-error-case', 'expression' => '|||bad|||', 'resource' => {},
        'error' => { 'class' => 'FHIRPath::ParseError' }
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(file.path)
      result = report[:cases].first

      assert_equal 'pass', result['classification']
      assert_equal 'FHIRPath::ParseError', result['actual_error']['class']
      assert_equal 'unexpected_token', result['actual_error']['code']
    end
  end

  def test_report_fields_include_harness_error_type
    vectors = [
      {
        'id' => 'harness-error-case', 'expression' => 'anything', 'resource' => {},
        'error' => { 'class' => 'FHIRPath::UnsupportedFeatureError', 'code' => 'unsupported' }
      }
    ]
    Tempfile.create('fhirpath-vector') do |file|
      file.write(vectors.map(&:to_json).join("\n"))
      file.write("\n")
      file.flush

      report = FHIRPath::VectorRunner.run(
        file.path,
        evaluator: ->(_vector) { raise FHIRPath::UnsupportedFeatureError.new('test', code: :unsupported) }
      )
      result = report[:cases].first

      assert_equal 'pass', result['classification']
      assert_equal 'FHIRPath::UnsupportedFeatureError', result['actual_error']['class']
      assert_equal 'unsupported', result['actual_error']['code']
    end
  end
end
