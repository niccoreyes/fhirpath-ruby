#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate a conformance report for a single corpus and write it to a file.
# This is a helper invoked by Rake tasks.
#
# Usage:
#   generate_conformance_report.rb MANIFEST_PATH OUTPUT_JSON [--baseline BASELINE_JSON]

require 'json'
require 'fileutils'
require_relative '../lib/fhirpath/conformance/importer'
require_relative '../lib/fhirpath/conformance/corpus_validator'

manifest_path = ARGV[0]
output_path = ARGV[1]
baseline_path = ARGV[2]

unless manifest_path && output_path
  raise ArgumentError,
        'usage: generate_conformance_report.rb MANIFEST OUTPUT [--baseline BASELINE]'
end

manifest = JSON.parse(File.read(manifest_path))
source_root = File.dirname(manifest_path)

importer = FHIRPath::Conformance::Importer.new(
  source_root: source_root,
  suite_path: manifest['source'],
  suite: manifest.fetch('suite', 'FHIR/fhir-test-cases'),
  suite_commit: manifest.fetch('suite_commit'),
  target: manifest.fetch('target'),
  model: manifest.fetch('model', 'plain'),
  fixture_root: manifest['fixture_root'],
  load_full_suite: manifest.fetch('load_full_suite', false)
)

records = importer.import
baseline = baseline_path && JSON.parse(File.read(baseline_path))
report = FHIRPath::Conformance::CorpusValidator.validate(records, baseline: baseline)

# Build the output report with all required metadata keys as strings.
def stringify_keys(obj)
  return obj if obj.is_a?(String) || obj.is_a?(Numeric) || obj.is_a?(TrueClass) || obj.is_a?(FalseClass) || obj.nil?

  return obj unless obj.is_a?(Hash)

  obj.each_with_object({}) do |(k, v), out|
    out[k.to_s] = stringify_keys(v)
  end
end

report_str = stringify_keys(report)

# Ensure classification_counts exists.
unless report_str['classification_counts']
  counts = report_str['record_counts'] || {}
  evaluable = counts.delete('evaluable') || 0
  report_str['classification_counts'] = counts.merge('evaluable' => evaluable)
end

# Merge manifest-level metadata (wins over any existing keys).
metadata = {
  'schema_version' => 1,
  'corpus' => manifest.fetch('corpus', File.basename(manifest_path, '.json')),
  'suite' => manifest.fetch('suite', 'FHIR/fhir-test-cases'),
  'suite_commit' => manifest.fetch('suite_commit'),
  'target' => manifest.fetch('target'),
  'model' => manifest.fetch('model', 'plain'),
  'source_sha' => manifest.fetch('suite_commit'),
  'corpus_digest' => report[:digest]
}
report_str.merge!(metadata)

FileUtils.mkdir_p(File.dirname(output_path))
File.write(output_path, JSON.pretty_generate(report_str))

exit(report[:valid] ? 0 : 1)
