#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates the full per-case conformance report artifact for a manifest.
# Unlike generate_conformance_report.rb (which emits validation counts), this
# writes every case with its classification and any evaluation error, which is
# the evidence referenced by docs/support-matrix.md.
#
# Usage:
#   generate_official_suite_report.rb [MANIFEST] [OUTPUT]

require 'json'
require 'fileutils'
require_relative '../lib/fhirpath'
require_relative '../lib/fhirpath/conformance/importer'
require_relative '../lib/fhirpath/vector_runner'

manifest_path = ARGV[0] || 'conformance/official-r4-core.json'
output_path = ARGV[1] || 'conformance/official-suite-report.json'
manifest = JSON.parse(File.read(manifest_path))

importer = FHIRPath::Conformance::Importer.new(
  source_root: File.dirname(manifest_path),
  suite_path: manifest.fetch('source'),
  suite: manifest.fetch('suite', 'FHIR/fhir-test-cases'),
  suite_commit: manifest.fetch('suite_commit'),
  target: manifest.fetch('target'),
  model: manifest.fetch('model', 'plain'),
  fixture_root: manifest['fixture_root'],
  load_full_suite: manifest.fetch('load_full_suite', false)
)

records = importer.import
vector_path = 'conformance/.tmp_case_records.jsonl'
begin
  File.write(vector_path, "#{records.map(&:to_json).join("\n")}\n")
  report = FHIRPath::VectorRunner.run(vector_path)
ensure
  FileUtils.rm_f(vector_path)
end

File.write(output_path, JSON.pretty_generate(report))
warn "wrote #{output_path}: #{report[:total]} cases, counts=#{report[:counts]}"
