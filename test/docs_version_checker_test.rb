# frozen_string_literal: true

require 'minitest/autorun'

# Test the docs version checker by verifying the actual repository state
class DocsVersionCheckerTest < Minitest::Test
  LIB_VERSION = '0.2.0.pre5'

  def test_library_version_is_correct
    require_relative '../lib/fhirpath/version'
    assert_equal LIB_VERSION, FHIRPath::VERSION
  end

  def test_readme_has_matching_version
    readme = File.read(File.join(__dir__, '..', 'README.md'))
    assert_match(/Version: `#{LIB_VERSION}`/, readme,
                 "README.md should show version #{LIB_VERSION}")
  end

  def test_api_docs_has_matching_version
    api_md = File.read(File.join(__dir__, '..', 'docs', 'api.md'))
    assert_match(/\(`#{LIB_VERSION}`\)/, api_md,
                 "docs/api.md should show version #{LIB_VERSION}")
  end

  def test_feature_matrix_has_matching_version
    feature_md = File.read(File.join(__dir__, '..', 'docs', 'feature-matrix.md'))
    assert_match(/`#{LIB_VERSION}`/, feature_md,
                 "docs/feature-matrix.md should show version #{LIB_VERSION}")
  end

  def test_support_matrix_has_matching_version
    support_md = File.read(File.join(__dir__, '..', 'docs', 'support-matrix.md'))
    assert_match(/\(`#{LIB_VERSION}`\)/, support_md,
                 "docs/support-matrix.md should show version #{LIB_VERSION}")
  end

  def test_release_checklist_has_matching_version
    checklist_md = File.read(File.join(__dir__, '..', 'docs', 'release-checklist.md'))
    assert_match(/\(`#{LIB_VERSION}`\)/, checklist_md,
                 "docs/release-checklist.md should show version #{LIB_VERSION}")
  end

  def test_changelog_unreleased_link_matches_version
    changelog = File.read(File.join(__dir__, '..', 'CHANGELOG.md'))
    # The [Unreleased] link should compare to the current version
    assert_match(%r{compare/v#{LIB_VERSION}\.\.\.HEAD}, changelog,
                 "CHANGELOG.md [Unreleased] link should compare to #{LIB_VERSION}")
  end

  def test_no_stale_version_references_in_docs
    doc_files = %w[README.md docs/api.md docs/feature-matrix.md docs/support-matrix.md docs/release-checklist.md]
    doc_files.each do |doc_file|
      path = File.join(__dir__, '..', doc_file)
      next unless File.exist?(path)

      content = File.read(path)
      matches = content.scan(/0\.2\.0\.pre\d+/).uniq
      assert_equal [LIB_VERSION], matches,
                   "#{doc_file} should only contain version #{LIB_VERSION}, found: #{matches.inspect}"
    end
  end
end
