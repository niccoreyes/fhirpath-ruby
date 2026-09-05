#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'rubygems/package'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'fhirpath/version'
require 'fhirpath/capability'

artifact = ARGV.fetch(0) { abort 'usage: verify_release.rb PATH_TO_GEM' }
release_tag = ENV.fetch('RELEASE_TAG', nil)

spec = Gem::Package.new(artifact).spec
metadata = spec.metadata
capability = FHIRPath::Capability.current
expected_version = release_tag&.sub(/\Av/, '')

if expected_version && spec.version.to_s != expected_version
  abort "artifact version #{spec.version} does not match tag #{release_tag}"
end
unless metadata['fhirpath_target'] == capability.fhirpath
  abort "artifact does not declare #{capability.fhirpath} as its FHIRPath target"
end
unless metadata['capability_set'] == capability.capability_set.join(',')
  abort 'artifact capability set does not match the runtime declaration'
end
unless metadata['release_status'] == FHIRPath::RELEASE_CHANNEL
  abort "artifact release status does not match #{FHIRPath::RELEASE_CHANNEL}"
end
abort 'artifact is missing the support matrix URI' unless metadata['support_matrix_uri'] == 'https://github.com/niccoreyes/fhirpath-ruby/blob/main/docs/support-matrix.md'
if FHIRPath::RELEASE_CHANNEL == 'pre-release' && !spec.version.prerelease?
  abort 'a stable version cannot be published while the channel is pre-release'
end
abort 'packaged gem is missing the support matrix' unless spec.files.include?('docs/support-matrix.md')

puts "Verified fhirpath #{spec.version}: FHIRPath #{metadata['fhirpath_target']}, " \
     "#{metadata['capability_set'].split(',').length} capabilities, #{metadata['release_status']}"
