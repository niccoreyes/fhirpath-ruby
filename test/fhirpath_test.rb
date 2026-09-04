# frozen_string_literal: true

require 'test_helper'

class FHIRPathTest < Minitest::Test
  def test_library_can_be_required_and_exposes_version
    assert defined?(FHIRPath)
    assert_equal FHIRPath::VERSION, FHIRPath.version
  end
end
