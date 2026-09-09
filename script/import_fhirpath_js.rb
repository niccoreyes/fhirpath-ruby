#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'fhirpath/vector_runner'
require 'fhirpath/conformance/fhirpath_js_importer'

# Import the pinned fhirpath.js compatibility corpus described by the allowlist
# manifest and emit one JSON record per adopted case. Records are validated
# against the strict corpus contract and the computed baseline is written so
# drift is caught by the validating gate.
#
# Usage:
#   import_fhirpath_js.rb [MANIFEST] [OUTPUT_JSONL] [--baseline PATH]

arg_manifest = ARGV.fetch(0) do
  abort "usage: #{File.basename($PROGRAM_NAME)} [MANIFEST] [OUTPUT_JSONL] [--baseline PATH]"
end
arg_output = ARGV[1]
baseline_index = ARGV.index('--baseline')
baseline_path = baseline_index ? ARGV[baseline_index + 1] : nil

manifest = File.expand_path(arg_manifest)
output = arg_output ? File.expand_path(arg_output) : File.expand_path('../conformance/fhirpath-js.jsonl', __dir__)
manifest_data = JSON.parse(File.read(manifest))
baseline_path ||= File.expand_path('../conformance/baselines/fhirpath-js.json', __dir__)

records = FHIRPath::Conformance::FHIRPathJSImporter.from_manifest(manifest).import
File.open(output, 'w') { |file| records.each { |record| file.puts JSON.generate(record) } }

report = FHIRPath::Conformance::CorpusValidator.validate_file(output)
unless report[:valid]
  warn report[:errors]
  abort "manifest import produced an invalid corpus (#{report[:errors].length} errors)"
end

# Run the corpus so the baseline records executable classifications (pass,
# defect, unsupported, host-dependent) rather than only input-time not-run.
run_report = FHIRPath::VectorRunner.run(output)

baseline = {
  'schema_version' => 1,
  'corpus' => 'fhirpath-js',
  'suite' => report[:corpus_suite],
  'suite_commit' => report[:source_sha],
  'target' => manifest_data['target'],
  'model' => manifest_data['model'],
  'total' => run_report[:total],
  'record_counts' => report[:record_counts],
  'classification_counts' => run_report[:counts],
  'capability_totals' => run_report[:capability_totals],
  'source_sha' => report[:source_sha],
  'corpus_digest' => report[:digest]
}
File.write(baseline_path, "#{JSON.pretty_generate(baseline)}\n")
puts "Imported #{records.length} fhirpath.js records -> #{output}"
puts "Baseline #{baseline_path}: #{report[:digest]}"
