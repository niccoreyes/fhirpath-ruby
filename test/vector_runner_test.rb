# frozen_string_literal: true

require 'test_helper'
require 'fhirpath/vector_runner'
require 'tempfile'

class FHIRPathVectorRunnerTest < Minitest::Test
  VECTOR_PATH = File.expand_path('../conformance/core.jsonl', __dir__)

  def test_runner_reports_passes_and_preserves_vector_provenance
    report = FHIRPath::VectorRunner.run(VECTOR_PATH)

    assert_equal 17, report[:total]
    assert_equal 17, report[:counts]['pass']
    assert_equal 0, report[:counts]['defect']
    assert_equal 0, report[:counts]['unsupported']
    assert_equal 17, report[:cases].length
    assert_equal 'fhirpath-py', report[:cases].first['origin']['suite']
  end

  def test_runner_requires_expected_error_class_and_code_and_preserves_expectation
    Tempfile.create('fhirpath-vector') do |file|
      file.write({
        id: 'singleton-error-001', target: '2.0.0', expression: '{1, 2} + 1',
        resource: {}, variables: {},
        error: { class: 'FHIRPath::SingletonError', code: 'singleton_required' },
        origin: { suite: 'manual', commit: 'working-tree', case: 'regression' }
      }.to_json)
      file.write("\n")
      file.flush

      result = FHIRPath::VectorRunner.run(file.path)[:cases].first

      assert_equal 'pass', result['classification']
      assert_equal 'FHIRPath::SingletonError', result['actual_error']['class']
      assert_equal 'singleton_required', result['actual_error']['code']
      assert_equal({ 'class' => 'FHIRPath::SingletonError', 'code' => 'singleton_required' }, result['error'])
    end
  end

  def test_runner_marks_a_wrong_expected_error_class_as_a_defect
    Tempfile.create('fhirpath-vector') do |file|
      file.write({
        id: 'wrong-error-class-001', expression: '{1, 2} + 1', resource: {}, variables: {},
        error: { class: 'FHIRPath::TypeError', code: 'singleton_required' }
      }.to_json)
      file.write("\n")
      file.flush

      result = FHIRPath::VectorRunner.run(file.path)[:cases].first

      assert_equal 'defect', result['classification']
      assert_equal 'FHIRPath::TypeError', result['error']['class']
    end
  end
end
