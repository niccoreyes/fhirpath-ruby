#!/usr/bin/env bash
set -euo pipefail

GEM_FILE=${1:?usage: $0 path/to/fhirpath.gem}

if [[ ! -f "$GEM_FILE" ]]; then
  printf 'gem artifact not found: %s\n' "$GEM_FILE" >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_LICENSE_PATH="$SCRIPT_DIR/../LICENSE"
TMP_HOME=$(mktemp -d)
trap 'rm -rf "$TMP_HOME"' EXIT

BASE_GEM_PATH=$(gem env gempath)
RUNTIME_GEM_PATH="$TMP_HOME/gems:$BASE_GEM_PATH"

# The dependency is already installed by Bundler or the Ruby runtime. The
# isolated destination verifies the package without downloading again.
GEM_HOME="$TMP_HOME/gems" GEM_PATH="$RUNTIME_GEM_PATH" gem install --local "$GEM_FILE" --install-dir "$TMP_HOME/gems" --no-document --ignore-dependencies

FHIRPATH_SOURCE_LICENSE="$SOURCE_LICENSE_PATH" GEM_HOME="$TMP_HOME/gems" GEM_PATH="$RUNTIME_GEM_PATH" ruby - "$GEM_FILE" <<'RUBY'
require 'rubygems'
require 'rubygems/package'

artifact = ARGV.fetch(0)
expected = Gem::Package.new(artifact).spec
installed = Gem::Specification.find_by_name('fhirpath')
abort 'installed version does not match the artifact' unless installed.version == expected.version
abort 'artifact does not declare the MIT license' unless expected.licenses == ['MIT']
abort 'runtime entry point is missing from the installed gem' unless File.file?(File.join(installed.full_gem_path, 'lib/fhirpath.rb'))
abort 'README is missing from the installed gem' unless File.file?(File.join(installed.full_gem_path, 'README.md'))
license_path = File.join(installed.full_gem_path, 'LICENSE')
source_license_path = ENV.fetch('FHIRPATH_SOURCE_LICENSE')
abort 'LICENSE is missing from the installed gem' unless File.file?(license_path)
abort 'packaged LICENSE differs from the checked-in license' unless File.binread(license_path) == File.binread(source_license_path)

gem 'fhirpath', installed.version.to_s
require 'fhirpath'
abort 'installed entry point did not expose FHIRPath' unless defined?(FHIRPath)
abort 'installed API smoke test returned the wrong result' unless FHIRPath.evaluate({}, '1 + 2').to_a == [3]

puts "Installed fhirpath #{installed.version} and evaluated 1 + 2 successfully"
RUBY
