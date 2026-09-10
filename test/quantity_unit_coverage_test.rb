# frozen_string_literal: true

require 'test_helper'

# UCUM coverage and Quantity capability cases from the official suite:
# Comparable1/2/3, testEquality28, testEquivalent22, testGreaterThan22,
# testGreatorOrEqual22, testLessOrEqual22, testLessThan22, testQuantity9,
# testMinus5, testPlusDate13/14/15/16/17.
class FHIRPathQuantityUnitCoverageTest < Minitest::Test
  def evaluate(expression)
    FHIRPath.evaluate({}, expression)
  end

  def first(expression)
    evaluate(expression).first
  end

  # --- extended UCUM atoms --------------------------------------------------

  def test_international_inch_atom_is_a_length_unit
    quantity = first("1 '[in_i]'")

    assert_equal '[in_i]', quantity.unit
    assert_equal BigDecimal('1'), quantity.value
    assert_equal [true], evaluate("1 'cm'.comparable(1 '[in_i]')").to_a
    assert_equal [true], evaluate("2.54 'cm' = 1 '[in_i]'").to_a
  end

  def test_avoirdupois_pound_atom_is_a_mass_unit
    quantity = first("185 '[lb_av]'")

    assert_equal '[lb_av]', quantity.unit
    assert_equal [true], evaluate("1 'kg'.comparable(1 '[lb_av]')").to_a
    assert_equal [true], evaluate("453.59237 'g' = 1 '[lb_av]'").to_a
  end

  def test_bracketed_second_atom_is_a_time_unit
    quantity = first("1 '[s]'")

    assert_equal '[s]', quantity.unit
    assert_equal [true], evaluate("60 '[s]' = 1 'min'").to_a
    assert_equal [false], evaluate("1 'cm'.comparable(1 '[s]')").to_a
  end

  def test_unbalanced_bracketed_units_are_still_rejected
    ['[in_i', '[lb_av'].each do |unit|
      error = assert_raises(FHIRPath::ParseError) { evaluate("1 '#{unit}'") }

      assert_equal :invalid_quantity, error.code
    end
  end

  # --- implicit UCUM exponents --------------------------------------------

  def test_implicit_ucum_exponents_use_the_digit_suffix
    assert_equal [true], evaluate("1 'm2' = 1 'm^2'").to_a
    assert_equal [true], evaluate("1 'cm3' = 1 'cm^3'").to_a
    assert_equal [true], evaluate("2.0 'cm' * 2.0 'm' = 0.040 'm2'").to_a
    assert_equal BigDecimal('10000'), evaluate("1 'm2' / 1 'cm2'").first
  end

  def test_implicit_exponent_still_honours_the_exponent_budget
    error = assert_raises(FHIRPath::ParseError) { evaluate("1 'm13'") }

    assert_equal :invalid_quantity, error.code
  end

  def test_implicit_exponent_does_not_swallow_multi_digit_atoms
    assert_equal [true], evaluate("1 'mmol' = 1 'mmol'").to_a
    assert_equal [true], evaluate("1000 'mmol' = 1 'mol'").to_a
    assert_equal [true], evaluate("1 'min' = 60 's'").to_a
  end

  # --- comparable() --------------------------------------------------------

  def test_comparable_returns_false_for_different_dimensions
    assert_equal [false], evaluate("1 'cm'.comparable(1 's')").to_a
    assert_equal [false], evaluate("1 'kg'.comparable(1 'm')").to_a
    assert_equal [true], evaluate("1 'mg'.comparable(1 'kg')").to_a
  end

  def test_comparable_returns_empty_for_an_empty_argument
    assert_empty evaluate("1 'cm'.comparable({})")
  end

  def test_comparable_requires_a_quantity_argument
    error = assert_raises(FHIRPath::TypeError) { evaluate("1 'cm'.comparable(1)") }

    assert_equal :expected_quantity, error.code
  end

  def test_comparable_on_an_empty_receiver_is_empty
    assert_empty evaluate("({}).comparable(1 'cm')")
  end

  # --- calendar durations for date arithmetic -----------------------------

  def test_calendar_duration_keywords_are_accepted_when_quoted
    %w[year month week day hour minute second millisecond].each do |unit|
      assert_instance_of FHIRPath::Quantity, first("1 '#{unit}'"), unit
    end
  end

  def test_quoted_calendar_month_subtraction_uses_calendar_semantics
    assert_equal [Date.new(1974, 11, 25)], evaluate("@1974-12-25 - 1 'month'").to_a
    assert_equal [Date.new(1973, 12, 26)], evaluate("@1973-12-25 + 1 'd'").to_a
    assert_equal [Date.new(1974, 1, 1)], evaluate("@1973-12-25 + 1 'wk'").to_a
  end

  def test_ucum_calendar_variable_units_are_rejected_for_date_arithmetic
    ["@1973-12-25 + 1 'mo'", "@1973-12-25 + 1 'a'", "@1975-12-25 + 1 'a'"].each do |expression|
      error = assert_raises(FHIRPath::EvaluationError) { evaluate(expression) }

      assert_equal :unsupported_temporal_unit, error.code, expression
    end
  end

  def test_calendar_duration_arithmetic_matches_the_keyword_form
    %w[week day hour minute second millisecond].each do |unit|
      keyword = evaluate("@1973-12-25T00:00:00.000+10:00 + 1 #{unit}").to_a
      quoted = evaluate("@1973-12-25T00:00:00.000+10:00 + 1 '#{unit}'").to_a

      assert_equal keyword, quoted, unit
    end
  end

  def test_quoted_calendar_months_and_years_still_support_equality
    assert_equal [true], evaluate("1 'month' = 1 'month'").to_a
    assert_equal [true], evaluate("12 'month' = 1 'year'").to_a
  end
end
