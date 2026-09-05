# frozen_string_literal: true

require 'test_helper'

module FHIRPathHostServicesAssertions
  private

  def assert_no_provider_secret(error, secret)
    diagnostics = [error.message, error.full_message, error.inspect, error.to_h.inspect]
    refute(diagnostics.any? { |diagnostic| diagnostic.include?(secret) })

    causes = []
    current = error
    while current
      causes << current
      current = current.cause
    end
    refute(causes.any? { |cause| cause.message.include?(secret) })
    causes
  end
end

class FHIRPathHostServicesTest < Minitest::Test
  include FHIRPathHostServicesAssertions

  def test_constant_provider_failures_are_sanitized_at_the_direct_boundary
    secret = 'synthetic-provider-secret-123456789'
    provider_errors = [
      RuntimeError.new("provider failed with #{secret}"),
      FHIRPath::HostError.new("provider failed with #{secret}", code: :provider_detail)
    ]

    provider_errors.each do |provider_error|
      host = FHIRPath::HostServices.new(
        constants: ->(_name, **_kwargs) { raise provider_error }
      )

      error = assert_raises(FHIRPath::HostError) do
        host.constant('api_key')
      end

      assert_equal :host_error, error.code
      assert_equal 'constant provider failed', error.message
      assert_nil error.span
      assert_nil error.expression
      assert_nil error.original_cause
      assert_equal({ code: :host_error, message: 'constant provider failed' }, error.to_h)
      causes = assert_no_provider_secret(error, secret)
      assert(causes.all?(FHIRPath::HostError))
    end
  end

  def test_constant_provider_failures_are_sanitized_through_evaluation
    secret = 'synthetic-provider-secret-123456789'
    provider_errors = [
      RuntimeError.new("provider failed with #{secret}"),
      FHIRPath::HostError.new("provider failed with #{secret}", code: :provider_detail)
    ]

    provider_errors.each do |provider_error|
      host = FHIRPath::HostServices.new(
        constants: ->(_name, **_kwargs) { raise provider_error }
      )

      error = assert_raises(FHIRPath::HostError) do
        FHIRPath.evaluate({}, '%api_key', host: host)
      end

      assert_equal :host_error, error.code
      assert_equal 'constant provider failed', error.message
      assert_equal '%api_key', error.expression
      assert_equal 0, error.span.offset
      assert_equal 8, error.span.length
      assert_nil error.original_cause
      assert_equal({ code: :host_error, message: 'constant provider failed',
                     span: { offset: 0, length: 8, end_offset: 8 }, expression: '%api_key' }, error.to_h)
      causes = assert_no_provider_secret(error, secret)
      assert(causes.all?(FHIRPath::HostError))
    end
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
      define_method(:fetch) do |name, mode:, context:|
        fetched = [name, mode, context.root.first_item]
        'ok'
      end
    end.new
    host = FHIRPath::HostServices.new(constant_provider: provider)

    result = FHIRPath.evaluate({ 'id' => 'one' }, '%tenant', host: host)

    assert_equal ['ok'], result.to_a
    assert_equal 'tenant', fetched[0]
    assert_nil fetched[1]
    assert_equal({ 'id' => 'one' }, fetched[2])
  end
end
