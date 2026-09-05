# frozen_string_literal: true

require 'test_helper'
require 'English'

# Issues #8 and #9: parser hardening.
#
# Issue #8: unbounded parser recursion. Deeply nested expressions
# (deep parentheses, long unary chains, nested function calls, indexers,
# and long flat expressions that build a deep AST) must raise a structured
# FHIRPath::Error with code :nesting_depth_exceeded rather than letting
# SystemStackError escape the FHIRPath::Error boundary.
#
# Issue #9: caller-owned source must not be frozen. parse/compile retain a
# snapshot of the source string and freeze it internally; they must not
# freeze the caller's mutable String.
class FHIRPathParserHardeningTest < Minitest::Test
  LIB = File.expand_path('../lib', __dir__)

  def test_deep_parenthesized_expression_under_limit_parses
    parsed = FHIRPath.parse(paren_expression(100))
    assert_instance_of FHIRPath::ParsedExpression, parsed
    assert_equal paren_expression(100), parsed.source
  end

  def test_nesting_just_below_documented_limit_parses
    parsed = FHIRPath.parse(paren_expression(FHIRPath::Parser::MAX_NESTING_DEPTH - 1))

    assert_instance_of FHIRPath::ParsedExpression, parsed
  end

  def test_nesting_at_documented_limit_raises_structured_error
    error = assert_raises(FHIRPath::ParseError) do
      FHIRPath.parse(paren_expression(FHIRPath::Parser::MAX_NESTING_DEPTH))
    end

    assert_equal :nesting_depth_exceeded, error.code
  end

  def test_deep_unary_chain_under_limit_parses
    parsed = FHIRPath.parse("#{'-' * 100}1")

    assert_instance_of FHIRPath::AST::UnaryExpression, parsed.ast
  end

  def test_deep_nested_function_calls_under_limit_parses
    parsed = FHIRPath.parse("#{'select(' * 100}1#{')' * 100}")

    assert_instance_of FHIRPath::AST::FunctionInvocation, parsed.ast
  end

  def test_deep_nested_indexers_under_limit_parses
    parsed = FHIRPath.parse("(1)#{'[0]' * 100}")

    assert_instance_of FHIRPath::AST::Indexer, parsed.ast
  end

  def test_long_flat_expression_building_deep_ast_parses_under_limit
    parsed = FHIRPath.parse(Array.new(101, '1').join(' + '))

    assert_instance_of FHIRPath::AST::BinaryExpression, parsed.ast
  end

  def test_absurdly_deep_parenthesization_raises_structured_error_not_system_stack_error
    # Run in a subprocess so a SystemStackError (if the guard regressed)
    # cannot escape into this minitest runner.
    status, output = run_subprocess(absurdly_deep_parse_script)

    assert status.success?,
           "expected structured :nesting_depth_exceeded, got exit #{status.exitstatus}: #{output}"
  end

  def test_unbounded_length_round_trip_does_not_crash_if_depth_guard_absent
    # A bare expression with mere binary nesting must not hit the depth guard;
    # only genuine nesting raises.
    assert_instance_of FHIRPath::ParsedExpression, FHIRPath.parse('1 + 2 + 3')
  end

  def test_nesting_exceeded_error_exposes_code_expression_and_span
    status, output = run_subprocess(absurdly_deep_parse_script)

    assert status.success?
    assert_match(/\Anesting_depth_exceeded\|FHIRPath::ParseError\|has_expression\|has_span\n?\z/, output)
  end

  def test_nesting_counter_does_not_leak_between_calls
    # A raising parse must not poison a subsequent independent parse: each
    # Parser instance owns its depth counter.
    assert_raises(FHIRPath::ParseError) { FHIRPath.parse(paren_expression(20_000)) }
    parsed = FHIRPath.parse('Patient.name.given')
    assert_equal 'Patient.name.given', parsed.source
  end

  # --- Issue #9: caller-owned source must not be frozen ---

  def test_parse_does_not_freeze_caller_string
    source = +'name'
    FHIRPath.parse(source)

    refute_predicate source, :frozen?
    source << '.given'
    assert_equal 'name.given', source
  end

  def test_compile_does_not_freeze_caller_string
    source = +'1 + 2'
    program = FHIRPath.compile(source)

    refute_predicate source, :frozen?
    source << ' * 3'
    assert_equal '1 + 2 * 3', source
    assert_equal [3], program.call({}).to_a
  end

  def test_parsed_source_is_a_frozen_independent_snapshot
    source = +'name'
    parsed = FHIRPath.parse(source)
    source << '.given'

    assert_predicate parsed.source, :frozen?
    assert_equal 'name', parsed.source
  end

  def test_mutating_caller_string_does_not_change_compiled_evaluation
    source = +'1 + 2'
    program = FHIRPath.compile(source)
    source << ' - 5'

    assert_equal [3], program.call({}).to_a
  end

  def test_already_frozen_source_still_compiles
    source = String.new('Patient.name.given').freeze
    program = FHIRPath.compile(source)

    assert_predicate source, :frozen?
    assert_equal 'Patient.name.given', program.source
  end

  private

  def paren_expression(depth)
    "#{'(' * depth}1#{')' * depth}"
  end

  def run_subprocess(script)
    output = IO.popen(['ruby', '-I', LIB, '-e', script], err: %i[child out], &:read)
    [$CHILD_STATUS, output]
  end

  def absurdly_deep_parse_script
    <<~RUBY
      require 'fhirpath'
      begin
        FHIRPath.parse('#{paren_expression(20_000)}')
        exit 10 # no error raised is a failure
      rescue SystemStackError
        exit 11 # guard failed: SystemStackError escaped the FHIRPath::Error boundary
      rescue FHIRPath::ParseError => e
        if e.code == :nesting_depth_exceeded
          puts [e.code, e.class, e.expression ? 'has_expression' : 'no_expression',
                e.span ? 'has_span' : 'no_span'].join('|')
          exit 0
        else
          warn "unexpected code \#{e.code}"
          exit 12
        end
      rescue FHIRPath::Error => e
        warn "unexpected error class \#{e.class}"
        exit 13
      end
    RUBY
  end
end
