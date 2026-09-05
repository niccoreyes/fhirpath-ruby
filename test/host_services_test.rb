# frozen_string_literal: true

require 'test_helper'

class FHIRPathHostServicesTest < Minitest::Test
  def test_constant_provider_failure_is_generic_and_retains_original_cause
    provider_error = RuntimeError.new('provider leaked sensitive-provider-value-123456789')
    provider = ->(_name, **_kwargs) { raise provider_error }
    host = FHIRPath::HostServices.new(constants: provider)

    error = assert_raises(FHIRPath::HostError) do
      FHIRPath.evaluate({}, '%api_key', host: host)
    end

    assert_equal :host_error, error.code
    assert_equal 'constant provider failed', error.message
    refute_includes error.message, 'sensitive-provider-value-123456789'
    refute_includes error.to_h[:message], 'sensitive-provider-value-123456789'
    assert_same provider_error, error.original_cause
  end

  def test_constant_provider_error_messages_are_redacted_even_for_fhirpath_errors
    provider_error = FHIRPath::HostError.new(
      'hard-coded sensitive-provider-value-123456789', code: :provider_detail
    )
    host = FHIRPath::HostServices.new(
      constants: ->(_name, **_kwargs) { raise provider_error }
    )

    error = assert_raises(FHIRPath::HostError) do
      FHIRPath.evaluate({}, '%api_key', host: host)
    end

    assert_equal :host_error, error.code
    assert_equal 'constant provider failed', error.message
    refute_includes error.to_h[:message], 'sensitive-provider-value-123456789'
    assert_same provider_error, error.original_cause
  end

  def test_missing_constant_provider_returns_a_predictable_unknown_constant_error
    error = assert_raises(FHIRPath::UnknownConstantError) do
      FHIRPath.evaluate({}, '%missing')
    end

    assert_equal :unknown_constant, error.code
    assert_equal 'unknown external constant: %missing', error.message
    assert_equal 0, error.span.offset
  end

  def test_constant_provider_is_not_called_when_variables_supply_the_constant
    calls = 0
    provider = lambda { |_name, **_kwargs|
      calls += 1
      raise IOError, 'unexpected provider I/O'
    }
    host = FHIRPath::HostServices.new(constants: provider)

    result = FHIRPath.evaluate({}, '%tenant', variables: { tenant: 'from variables' }, host: host)

    assert_equal ['from variables'], result.to_a
    assert_equal 0, calls
  end

  def test_shared_host_configuration_supports_reentrant_constant_evaluation
    host = nil
    calls = []
    host = FHIRPath::HostServices.new(
      constants: lambda { |name, context:, **_kwargs|
        calls << [name, context]
        name == 'outer' ? FHIRPath.evaluate({}, '%inner', host: host).first_item : 'inner'
      }
    )

    result = FHIRPath.evaluate({}, '%outer', host: host)

    assert_equal ['inner'], result.to_a
    assert_equal %w[outer inner], calls.map(&:first)
    refute_same calls[0][1], calls[1][1]
    assert host.frozen?
  end

  def test_constant_provider_interface_can_be_injected_without_any_implicit_io
    fetched = nil
    provider = Class.new(FHIRPath::ConstantProvider) do
      define_method(:fetch) { |name, mode:, context:| fetched = [name, mode, context.root.first_item]; 'ok' }
    end.new
    host = FHIRPath::HostServices.new(constant_provider: provider)

    result = FHIRPath.evaluate({ 'id' => 'one' }, '%tenant', host: host)

    assert_equal ['ok'], result.to_a
    assert_equal 'tenant', fetched[0]
    assert_nil fetched[1]
    assert_equal({ 'id' => 'one' }, fetched[2])
  end
end
