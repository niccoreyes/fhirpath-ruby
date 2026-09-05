# frozen_string_literal: true

require 'json'
require_relative 'errors'
require_relative 'conformance/importer'

module FHIRPath
  # Small, optional JSONL differential-vector runner. It is deliberately kept
  # outside the evaluator's runtime path and does not require Python.
  module VectorRunner
    CLASSIFICATIONS = %w[pass defect unsupported host-dependent not-run].freeze

    module_function

    def run(path, evaluator: nil)
      cases = File.foreach(path).with_index(1).each_with_object([]) do |(line, line_number), results|
        next if line.strip.empty?

        vector = JSON.parse(line)
        results << execute(vector, line_number, evaluator: evaluator)
      end
      counts = CLASSIFICATIONS.each_with_object({}) { |name, result| result[name] = 0 }
      cases.each { |result| counts[result['classification']] += 1 }
      {
        total: cases.length,
        counts: counts,
        capability_totals: capability_totals(cases),
        cases: cases
      }
    end

    def execute(vector, line_number, evaluator: nil)
      return result_for(vector, line_number, 'not-run').merge('actual' => nil) if vector['classification'] == 'not-run'

      values = evaluate(vector, evaluator).to_a
      classification = if values == vector.fetch('expected', []) && !vector['error']
                         'pass'
                       else
                         'defect'
                       end
      result_for(vector, line_number, classification).merge('actual' => values)
    rescue UnsupportedFeatureError => e
      error_result(vector, line_number, classify_error(vector, e, 'unsupported'), e)
    rescue HostError => e
      error_result(vector, line_number, classify_error(vector, e, 'host-dependent'), e)
    rescue Error => e
      error_result(vector, line_number, classify_error(vector, e, 'defect'), e)
    rescue StandardError => e
      error_result(vector, line_number, 'defect', e)
    end

    def evaluate(vector, evaluator = nil)
      return evaluator.call(vector) if evaluator

      FHIRPath.evaluate(vector['resource'] || {}, vector.fetch('expression'),
                        variables: vector['variables'] || {}, model: vector['model'])
    end

    def error_result(vector, line_number, classification, error)
      result_for(vector, line_number, classification).merge(
        'actual' => nil,
        'actual_error' => serialize_error(error)
      )
    end

    def expected_error_matches?(expected, error)
      return error.is_a?(Error) if expected == true
      return false unless expected

      class_matches = !expected['class'] || expected['class'] == error.class.name
      actual_code = error.respond_to?(:code) ? error.code.to_s : nil
      code_matches = !expected['code'] || expected['code'].to_s == actual_code
      class_matches && code_matches
    end

    def classify_error(vector, error, fallback)
      return 'pass' if expected_error_matches?(vector['error'], error)
      return 'defect' if vector['error']

      fallback
    end

    def result_for(vector, line_number, classification)
      vector.merge(result_fields(vector, line_number, classification))
    end

    def result_fields(vector, line_number, classification)
      origin = vector['origin'] || {}
      {
        'line' => line_number,
        'suite' => result_value(vector, 'suite', origin['suite']),
        'suite_commit' => result_value(vector, 'suite_commit', origin['suite_commit'] || origin['commit']),
        'input_fixture' => vector.fetch('input_fixture', nil),
        'model' => result_value(vector, 'model', 'plain'),
        'host_features' => result_value(vector, 'host_features', Capability.current.host_features),
        'target' => result_value(vector, 'target', Capability.current.fhirpath),
        'expected' => vector.fetch('expected', []),
        'classification' => classification
      }
    end

    def result_value(vector, key, fallback)
      vector[key] || fallback
    end

    def serialize_error(error)
      serialized = if error.respond_to?(:to_h)
                     { 'class' => error.class.name }.merge(error.to_h.transform_keys(&:to_s))
                   else
                     { 'class' => error.class.name, 'message' => error.message }
                   end
      serialized['code'] = error.code.to_s if error.respond_to?(:code)
      serialized
    end

    def capability_totals(cases)
      cases.group_by { |result| result['capability'] || 'unspecified' }
           .transform_values do |capability_cases|
             counts = CLASSIFICATIONS.each_with_object({}) { |name, result| result[name] = 0 }
             capability_cases.each { |result| counts[result['classification']] += 1 }
             { total: capability_cases.length, counts: counts }
           end
    end
  end
end
