# frozen_string_literal: true

require_relative 'lib/fhirpath/version'

Gem::Specification.new do |spec|
  spec.name = 'fhirpath'
  spec.version = FHIRPath::VERSION
  spec.authors = ['Nicco Reyes']
  spec.summary = 'A Ruby foundation for FHIRPath'
  spec.description =
    'A prototype Ruby-native scaffold for the HL7 FHIRPath expression language, ' \
    'with a deliberately limited supported surface.'
  spec.homepage = 'https://github.com/niccoreyes/fhirpath-ruby'
  # CI verifies Ruby 3.2 and 3.3. Do not claim support for older Rubies until
  # they have a maintained, reproducible CI lane.
  spec.required_ruby_version = '>= 3.2.0'
  spec.require_paths = ['lib']
  spec.add_dependency 'bigdecimal', '>= 3.0'

  # The project is released under the permissive MIT license. Keep this
  # metadata synchronized with the checked-in LICENSE file.
  spec.license = 'MIT'
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = 'https://github.com/niccoreyes/fhirpath-ruby/issues'
  spec.metadata['documentation_uri'] = 'https://github.com/niccoreyes/fhirpath-ruby/blob/main/docs/api.md'
  spec.metadata['changelog_uri'] = 'https://github.com/niccoreyes/fhirpath-ruby/blob/main/CHANGELOG.md'

  spec.files = Dir[
    'lib/**/*',
    'README.md',
    'CHANGELOG.md',
    'CONTRIBUTING.md',
    'SECURITY.md',
    'LICENSE',
    'Gemfile',
    'Rakefile',
    '.rubocop.yml',
    'docs/api.md',
    'docs/architecture.md',
    'docs/conformance.md',
    'docs/feature-matrix.md',
    'docs/first-slice.md',
    'docs/release-checklist.md',
    'conformance/core.jsonl',
    'script/run_vectors.rb'
  ].select { |path| File.file?(path) }

  spec.metadata['rubygems_mfa_required'] = 'true'
end
