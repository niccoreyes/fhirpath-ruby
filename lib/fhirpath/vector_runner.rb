# frozen_string_literal: true

require 'json'

module FHIRPath
  # Small, optional JSONL differential-vector runner. It is deliberately kept
  # outside the evaluator's runtime path and does not require Python.
  module VectorRunner
    CLASSIFICATIONS = %w[pass defect unsupported host-dependent not-run].freeze

    module_function

    def run(path)
      cases = File.foreach(path).with_index(1).each_with_object([]) do |(line, line_number), results|
        next if line.strip.empty?

        vector = JSON.parse(line)
        results << execute(vector, line_number)
      end
      counts = CLASSIFICATIONS.each_with_object({}) { |name, result| result[name] = 0 }
      cases.each { |result| counts[result['classification']] += 1 }
      { total: cases.length, counts: counts, cases: cases }
    end

    def execute(vector, line_number)
      values = evaluate(vector).to_a
      vector.merge(
        'line' => line_number,
        'classification' => vector['error'] || values != vector['expected'] ? 'defect' : 'pass',
        'actual' => values
      )
    rescue UnsupportedFeatureError => e
      error_result(vector, line_number, 'unsupported', e)
    rescue HostError => e
      error_result(vector, line_number, 'host-dependent', e)
    rescue Error => e
      classification = expected_error_matches?(vector['error'], e) ? 'pass' : 'defect'
      error_result(vector, line_number, classification, e)
    rescue StandardError => e
      error_result(vector, line_number, 'defect', e)
    end

    def evaluate(vector)
      FHIRPath.evaluate(vector['resource'] || {}, vector.fetch('expression'),
                        variables: vector['variables'] || {}, model: vector['model'])
    end

    def error_result(vector, line_number, classification, error)
      serialized = if error.respond_to?(:to_h)
                     { 'class' => error.class.name }.merge(error.to_h.transform_keys(&:to_s))
                   else
                     { 'class' => error.class.name, 'message' => error.message }
                   end
      serialized['code'] = error.code.to_s if error.respond_to?(:code)
      vector.merge('line' => line_number, 'classification' => classification,
                   'actual_error' => serialized)
    end

    def expected_error_matches?(expected, error)
      return false unless expected

      class_matches = !expected['class'] || expected['class'] == error.class.name
      code_matches = !expected['code'] || expected['code'].to_s == error.code.to_s
      class_matches && code_matches
    end
  end
end
