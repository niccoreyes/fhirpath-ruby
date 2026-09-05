#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'fhirpath/vector_runner'

source_root = ARGV.fetch(0) do
  abort "usage: #{File.basename($PROGRAM_NAME)} FHIR_TEST_CASES_CHECKOUT [MANIFEST]"
end
manifest = ARGV[1] || File.expand_path('../conformance/official-r4-core.json', __dir__)

records = FHIRPath::Conformance::Importer.from_manifest(manifest, source_root: source_root).import
records.each { |record| puts JSON.generate(record) }
