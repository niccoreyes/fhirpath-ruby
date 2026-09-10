# frozen_string_literal: true

require 'test_helper'
require 'fhirpath/conformance/importer'
require 'tmpdir'

# The official suite omits the `type` attribute on some <output> elements
# (notably the Comparable/Precision/HighBoundary/LowBoundary groups). Those
# values are FHIRPath literals and must be normalised to the same Ruby values
# the evaluator produces, otherwise the case can never match.
class FHIRPathUntypedOutputTest < Minitest::Test
  def import_output(inner)
    Dir.mktmpdir('fhirpath-import') do |root|
      File.write(File.join(root, 'tests.xml'), <<~XML)
        <tests>
          <group name="core">
            <test name="case">
              <expression>1</expression>
              #{inner}
            </test>
          </group>
        </tests>
      XML

      records = FHIRPath::Conformance::Importer.new(
        source_root: root, suite_path: 'tests.xml', suite_commit: 'abc123'
      ).import
      yield records.first['expected']
    end
  end

  def test_untyped_boolean_output_is_normalised
    import_output('<output>true</output>') { |expected| assert_equal [true], expected }
    import_output('<output>false</output>') { |expected| assert_equal [false], expected }
  end

  def test_untyped_integer_output_is_normalised
    import_output('<output>4</output>') { |expected| assert_equal [4], expected }
    import_output('<output>-120</output>') { |expected| assert_equal [-120], expected }
  end

  def test_untyped_decimal_output_is_normalised
    import_output('<output>1.58650000</output>') do |expected|
      assert_equal [BigDecimal('1.5865')], expected
    end
    import_output('<output>-0.0</output>') do |expected|
      assert_equal [BigDecimal('0')], expected
    end
  end

  def test_untyped_temporal_output_is_normalised
    import_output('<output>@2014-12</output>') do |expected|
      value = expected.first

      assert_instance_of FHIRPath::Temporal, value
      assert_equal 6, value.precision
      assert_equal Date.new(2014, 12, 1), value.value
    end

    import_output('<output>@T10:30:00.000</output>') do |expected|
      value = expected.first

      assert_equal :time, value.kind
      assert_equal 9, value.precision
    end
  end

  def test_untyped_quantity_output_is_normalised
    import_output("<output>1.58750000 'm'</output>") do |expected|
      value = expected.first

      assert_instance_of FHIRPath::Quantity, value
      assert_equal BigDecimal('1.5875'), value.value
      assert_equal 'm', value.unit
    end
  end

  def test_untyped_plain_string_output_stays_a_string
    import_output('<output>Peter</output>') { |expected| assert_equal ['Peter'], expected }
  end

  def test_typed_outputs_are_unchanged
    import_output('<output type="decimal">0.5</output>') { |expected| assert_equal ['0.5'], expected }
    import_output('<output type="date">@1974-01-01</output>') do |expected|
      assert_equal [{ '$type' => 'date', 'value' => '@1974-01-01' }], expected
    end
  end
end
