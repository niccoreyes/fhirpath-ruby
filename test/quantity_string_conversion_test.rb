# frozen_string_literal: true

require 'test_helper'

# toString() / convertsToString() / toQuantity() for the Quantity and String
# receivers the official suite exercises (issue #94 residual):
# testQuantityLiteralWkToString, testQuantityLiteralConvertsToString,
# testStringQuantityDayLiteralToQuantity.
#
# This is deliberately narrow: the wider conversion family (convertsTo* and
# toXxx across every type) belongs to issue #98.
class FHIRPathQuantityStringConversionTest < Minitest::Test
  def evaluate(expression)
    FHIRPath.evaluate({}, expression)
  end

  def test_quantity_to_string_uses_the_fhirpath_literal_form
    assert_equal ["1 'wk'"], evaluate("1 'wk'.toString()").to_a
    assert_equal ["1.587 'cm'"], evaluate("1.587 'cm'.toString()").to_a
    assert_equal ["-2 'mg'"], evaluate("(-2 'mg').toString()").to_a
  end

  def test_quantity_converts_to_string
    assert_equal [true], evaluate("1 'wk'.convertsToString()").to_a
    assert_equal [true], evaluate("1.587 'cm'.convertsToString()").to_a
  end

  def test_string_to_quantity_accepts_a_calendar_duration_name
    assert_equal [true], evaluate("'1 day'.toQuantity() = 1 'd'").to_a
    assert_equal [false], evaluate("'1 day'.toQuantity() = 1 'wk'").to_a
  end

  def test_string_to_quantity_accepts_a_quoted_ucum_unit
    assert_equal [true], evaluate("'1 \\'wk\\''.toQuantity() = 1 'wk'").to_a
    assert_equal [true], evaluate("'1.5 \\'mmol/L\\''.toQuantity() = 1.5 'mmol/L'").to_a
  end

  def test_string_to_quantity_accepts_a_dimensionless_number
    assert_equal [true], evaluate("'1.0'.toQuantity() = 1.0 '1'").to_a
  end

  def test_string_to_quantity_rejects_a_bare_ucum_code
    assert_empty evaluate("'1 wk'.toQuantity()")
    assert_empty evaluate("'1.a'.toQuantity()")
    assert_empty evaluate("'hello'.toQuantity()")
  end

  def test_conversions_on_an_empty_receiver_are_empty
    assert_empty evaluate('({}).toString()')
    assert_empty evaluate('({}).convertsToString()')
    assert_empty evaluate('({}).toQuantity()')
  end
end
