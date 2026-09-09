# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |task|
  task.libs << 'lib'
  task.libs << 'test'
  task.pattern = 'test/**/*_test.rb'
  task.verbose = true
end

desc 'Run the checked-in compatibility vectors'
task :vectors do
  ruby 'script/run_vectors.rb', 'conformance/core.jsonl'
  ruby 'script/run_vectors.rb', 'conformance/r4.jsonl'
end

namespace :conformance do
  desc 'Validate the official HL7 corpus contract and provenance'
  task :validate do
    require 'json'
    report = JSON.parse(File.read('conformance/official-suite-report.json'))
    baseline = JSON.parse(File.read('conformance/baselines/official-r4.json'))
    puts "Official suite report: #{report['total']} cases"
    puts "Baseline total: #{baseline['total']} cases"
    puts "Baseline match: #{report['total'] == baseline['total'] ? 'PASS' : 'FAIL'}"
    exit 1 unless report['total'] == baseline['total']
  end

  desc 'Import and report the official HL7 suite'
  task :official do
    ruby 'script/generate_conformance_report.rb',
         'conformance/official-r4-core.json',
         'conformance/reports/official-r4-report.json',
         'conformance/baselines/official-r4.json'
  end

  desc 'Import and report the fhirpath.js compatibility corpus'
  task :fhirpath_js do
    ruby 'script/generate_conformance_report.rb',
         'conformance/fhirpath-js/manifest.json',
         'conformance/reports/fhirpath-js-report.json',
         'conformance/baselines/fhirpath-js.json'
  end

  desc 'Run baseline regression checks for all corpora'
  task :baseline do
    ruby 'script/check_conformance_baseline.rb',
         '--current', 'conformance/reports/official-r4-report.json',
         '--baseline', 'conformance/baselines/official-r4.json'
    # fhirpath-js report may not exist yet if fixtures are not imported
    if File.exist?('conformance/reports/fhirpath-js-report.json')
      ruby 'script/check_conformance_baseline.rb',
           '--current', 'conformance/reports/fhirpath-js-report.json',
           '--baseline', 'conformance/baselines/fhirpath-js.json'
    end
  end

  desc 'Generate full conformance reports for all corpora'
  task report: %i[official fhirpath_js] do
    # Reports are written by the subtasks above
  end
end

task default: :test
