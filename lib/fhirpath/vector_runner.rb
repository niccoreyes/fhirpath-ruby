# frozen_string_literal: true

require 'json'
require 'bigdecimal'
require_relative 'errors'
require_relative 'temporal'
require_relative 'conformance/importer'
require_relative 'conformance/corpus_validator'

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

      if vector['error']
        # Error expected - try to evaluate and see if we get the expected error
        begin
          evaluate(vector, evaluator)
          # Evaluation succeeded but we expected an error -> defect
          error_result(vector, line_number, 'defect', StandardError.new('expected error but evaluation succeeded'))
        rescue UnsupportedFeatureError => e
          error_result(vector, line_number, classify_error(vector, e, 'unsupported'), e)
        rescue HostError => e
          error_result(vector, line_number, classify_error(vector, e, 'host-dependent'), e)
        rescue StandardError => e
          error_result(vector, line_number, classify_error(vector, e, 'defect'), e)
        end
      else
        # No error expected - evaluation should succeed and match expected values
        begin
          values = evaluate(vector, evaluator).to_a
          classification = expected_equal?(values, vector.fetch('expected', [])) ? 'pass' : 'defect'
          result_for(vector, line_number, classification).merge('actual' => values)
        rescue UnsupportedFeatureError => e
          # A capability the engine does not implement is unsupported, not a
          # defect in a behaviour the engine claims to support.
          error_result(vector, line_number, 'unsupported', e)
        rescue HostError => e
          error_result(vector, line_number, 'host-dependent', e)
        rescue StandardError => e
          error_result(vector, line_number, 'defect', e)
        end
      end
    end

    def evaluate(vector, evaluator = nil)
      return evaluator.call(vector) if evaluator

      # Conformance records spell the default out as `plain`; the public API
      # treats `nil` as the PlainModel default and rejects unknown release
      # strings, so map the explicit plain marker to nil before dispatch.
      model = vector['model']
      model = nil if model.to_s == 'plain'
      FHIRPath.evaluate(vector['resource'] || {}, vector.fetch('expression'),
                        variables: vector['variables'] || {}, model: model)
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

      class_matches = true
      if expected['class']
        expected_class_name = expected['class'].to_s
        if expected_class_name.start_with?('FHIRPath::')
          expected_class = begin
            Object.const_get(expected_class_name)
          rescue NameError, TypeError
            nil
          end
          class_matches = expected_class.is_a?(Class) || expected_class.is_a?(Module)
          class_matches &&= error.is_a?(expected_class) if class_matches
        else
          class_matches = false
        end
      end

      actual_code = error.respond_to?(:code) ? error.code.to_s : nil
      (!expected['code'] || expected['code'].to_s == actual_code) && class_matches
    end

    def classify_error(vector, error, fallback)
      return 'pass' if expected_error_matches?(vector['error'], error)
      return 'defect' if vector['error']

      fallback
    end

    def result_for(vector, line_number, classification)
      vector.merge(result_fields(vector, line_number, classification))
    end

    # Expected values travel through JSONL, so a Decimal or temporal value that
    # the importer normalised is read back as its JSON form (a String), and a
    # typed suite output (`{"$type"=>"date","value"=>"@1974-01-01"}`) is a
    # structured object rather than the value it denotes. Try value equality
    # first, then the comparable forms (a literal's underlying
    # Date/DateTime/Time, a typed output resolved to the value it denotes), then
    # the canonical JSON form of both representations.
    def expected_equal?(values, expected)
      actual = values.map { |value| comparand(value) }
      wanted = expected.map { |value| comparand(value) }
      return true if values == expected || actual == wanted || same_json?(values, expected)

      same_json?(actual, wanted)
    rescue StandardError
      false
    end

    def same_json?(left, right)
      JSON.generate(left) == JSON.generate(right)
    rescue StandardError
      false
    end

    # Reduces a value to the form used for comparison: a literal's underlying
    # Date/DateTime/Time (so a precision-carrying literal compares by instant)
    # and a typed expected output to the value it denotes.
    def comparand(value)
      return value.value if value.is_a?(Temporal)
      return value unless typed_output?(value)

      resolve_typed_output(value['$type'], value['value'])
    end

    def typed_output?(value)
      value.is_a?(Hash) && value['$type']
    end

    def resolve_typed_output(type, text)
      case type.to_s
      when 'boolean' then text.to_s.strip.casecmp('true').zero?
      when 'integer' then Integer(text.to_s.strip, 10)
      when 'decimal' then BigDecimal(text.to_s)
      when 'date', 'dateTime', 'time' then temporal_comparand(text)
      else text
      end
    rescue ArgumentError, TypeError
      text
    end

    def temporal_comparand(text)
      literal = text.to_s.strip
      literal = "@#{literal}" unless literal.start_with?('@')
      value = FHIRPath::Parser.parse(literal).ast.value
      value.is_a?(Temporal) ? value.value : value
    rescue StandardError
      text
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
