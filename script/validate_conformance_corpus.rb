#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'fhirpath/vector_runner'

# Validate a conformance corpus (JSONL of vector records) against the strict,
# deterministic corpus contract, and optionally compare it against a checked-in
# baseline. Exits non-zero when the corpus is malformed, provenance-incomplete,
# non-deterministic, or when it has drifted from the declared baseline.
#
# Usage:
#   validate_conformance_corpus.rb PATH_TO_JSONL [--baseline BASELINE_JSON]
#       [--output-baseline PATH] [--json]
#
#   --baseline PATH      Compare digest / record counts against the baseline.
#   --output-baseline P  Write the computed baseline metadata to PATH.
#   --json               Emit the full report as JSON (default is human summary).

def baseline_payload(report)
  {
    'schema_version' => 1,
    'corpus' => File.basename(report[:source], '.jsonl').tr('-.', '_'),
    'suite' => report[:corpus_suite],
    'suite_commit' => report[:source_sha],
    'total' => report[:total],
    'record_counts' => report[:record_counts],
    'capability_totals' => report[:capability_totals],
    'corpus_digest' => report[:digest]
  }
end

def print_summary(path, report, baseline)
  puts "Corpus: #{path}"
  puts "  status: #{report[:status]}"
  puts "  total: #{report[:total]}"
  puts "  source_sha: #{report[:source_sha]}"
  puts "  digest: #{report[:digest]}"
  print_counts(report)
  print_drift(report, baseline)
  print_errors(report) unless report[:valid]
end

def print_counts(report)
  report[:record_counts].each do |key, value|
    puts "  #{key}: #{value}" if value.positive?
  end
end

def print_drift(report, baseline)
  expected = baseline && baseline['corpus_digest']
  return unless expected && expected != report[:digest]

  puts "  BASELINE DIGEST DRIFT: #{expected} != #{report[:digest]}"
end

def print_errors(report)
  puts '  ERRORS:'
  report[:errors].each { |error| puts "    - #{error}" }
end

def usage
  "usage: #{File.basename($PROGRAM_NAME)} PATH_TO_JSONL " \
    '[--baseline BASELINE_JSON] [--output-baseline PATH] [--json]'
end

path = ARGV.fetch(0) { abort usage }

args = ARGV[1..] || []
options = {}
args.each_slice(2) { |key, value| options[key] = value }
baseline_path = options['--baseline']
output_path = options['--output-baseline']
emit_json = args.include?('--json')

baseline = baseline_path && JSON.parse(File.read(baseline_path))
report = FHIRPath::Conformance::CorpusValidator.validate_file(path, baseline: baseline)

if output_path && report[:valid]
  output_dir = File.dirname(output_path)
  FileUtils.mkdir_p(output_dir) unless output_dir == '.'
  File.write(output_path, JSON.pretty_generate(baseline_payload(report)))
end

if emit_json
  puts JSON.pretty_generate(report)
else
  print_summary(path, report, baseline)
end

exit(report[:valid] ? 0 : 1)
