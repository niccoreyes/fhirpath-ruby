# frozen_string_literal: true

require_relative 'lib/fhirpath/version'

Gem::Specification.new do |spec|
  spec.name = 'fhirpath'
  spec.version = FHIRPath::VERSION
  spec.authors = ['Nicco Reyes']
  spec.summary = 'A Ruby foundation for FHIRPath'
  spec.description = 'An initial Ruby foundation for a future implementation of the HL7 FHIRPath expression language.'
  spec.homepage = 'https://github.com/niccoreyes/fhirpath-ruby'
  spec.required_ruby_version = '>= 2.6.0'
  spec.require_paths = ['lib']

  # The project license is intentionally undecided while the architecture is
  # being established. See README.md for the current redistribution status.
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = 'https://github.com/niccoreyes/fhirpath-ruby/issues'

  spec.files = Dir[
    'lib/**/*',
    'README.md',
    'LICENSE',
    'Gemfile',
    'Rakefile',
    '.rubocop.yml'
  ].select { |path| File.file?(path) }

  spec.add_development_dependency 'minitest', '~> 5.16'
  spec.add_development_dependency 'rake', '~> 13.0'
  # RuboCop 1.50 is the last line compatible with Ruby 2.6.
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
