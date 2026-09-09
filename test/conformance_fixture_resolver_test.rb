# frozen_string_literal: true

require 'test_helper'
require 'fhirpath/conformance/fhir_xml_converter'
require 'fhirpath/conformance/fixture_resolver'
require 'tmpdir'
require 'fileutils'

class FHIRPathConformanceFixtureResolverTest < Minitest::Test
  def test_xml_converter_parses_simple_patient_with_primitives
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <id value="example"/>
        <active value="true"/>
        <name>
          <family value="Chalmers"/>
          <given value="Peter"/>
          <given value="James"/>
        </name>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 'Patient', json['resourceType']
    assert_equal 'example', json['id']
    assert_equal true, json['active']
    assert_equal 'Chalmers', json['name']['family']
    assert_equal %w[Peter James], json['name']['given']
  end

  def test_xml_converter_handles_namespaces_correctly
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <meta>
          <versionId value="1"/>
        </meta>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 'Patient', json['resourceType']
    assert_equal '1', json['meta']['versionId']
  end

  def test_xml_converter_handles_repeated_elements_as_arrays
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <name>
          <family value="Smith"/>
        </name>
        <name>
          <family value="Jones"/>
        </name>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 'Patient', json['resourceType']
    assert_equal 2, json['name'].length
    assert_equal 'Smith', json['name'][0]['family']
    assert_equal 'Jones', json['name'][1]['family']
  end

  def test_xml_converter_handles_primitive_extensions_in_standard_shape
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <name>
          <family value="Chalmers">
            <extension url="http://example.org/family-extension">
              <valueString value="extended"/>
            </extension>
          </family>
        </name>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    name = json['name']
    assert_equal 'Patient', json['resourceType']
    assert_equal 'Chalmers', name['family']
    # FHIR JSON: value stays at <name>, extension moves to _<name>.extension
    assert_equal [{ 'url' => 'http://example.org/family-extension',
                    'valueString' => 'extended' }],
                 name['_family']['extension']
  end

  def test_xml_converter_handles_choice_fields
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <deceasedDateTime value="2020-01-01T10:00:00Z"/>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 'Patient', json['resourceType']
    assert_equal '2020-01-01T10:00:00Z', json['deceasedDateTime']
  end

  def test_xml_converter_handles_contained_resources
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <id value="example"/>
        <contained>
          <Organization>
            <id value="org1"/>
            <name value="Acme Healthcare"/>
          </Organization>
        </contained>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 'Patient', json['resourceType']
    assert_equal 'example', json['id']
    assert_equal 1, json['contained'].length
    assert_equal 'Organization', json['contained'][0]['resourceType']
    assert_equal 'org1', json['contained'][0]['id']
    assert_equal 'Acme Healthcare', json['contained'][0]['name']
  end

  def test_xml_converter_handles_xhtml_narrative
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <text>
          <status value="generated"/>
          <div xmlns="http://www.w3.org/1999/xhtml">
            <p>Patient Peter Chalmers</p>
          </div>
        </text>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 'Patient', json['resourceType']
    assert_equal 'generated', json['text']['status']
    assert_kind_of String, json['text']['div']
    assert_includes json['text']['div'], '<p>Patient Peter Chalmers</p>'
  end

  def test_xml_converter_handles_decimal_values
    xml = <<~XML
      <Observation xmlns="http://hl7.org/fhir">
        <valueQuantity>
          <value value="123.456"/>
          <unit value="mg"/>
          <system value="http://unitsofmeasure.org"/>
          <code value="mg"/>
        </valueQuantity>
      </Observation>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 'Observation', json['resourceType']
    assert_equal '123.456', json['valueQuantity']['value']
    assert_equal 'mg', json['valueQuantity']['unit']
  end

  def test_xml_converter_handles_dates_and_times
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <birthDate value="1974-12-25"/>
        <deceasedDateTime value="2020-01-01T10:00:00Z"/>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal '1974-12-25', json['birthDate']
    assert_equal '2020-01-01T10:00:00Z', json['deceasedDateTime']
  end

  def test_xml_converter_handles_references
    xml = <<~XML
      <Observation xmlns="http://hl7.org/fhir">
        <subject>
          <reference value="Patient/example"/>
        </subject>
      </Observation>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 'Observation', json['resourceType']
    assert_equal 'Patient/example', json['subject']['reference']
  end

  def test_xml_converter_types_numeric_primitives
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <telecom>
          <system value="phone"/>
          <value value="(03) 5555 6473"/>
          <rank value="2"/>
        </telecom>
        <deceasedBoolean value="false"/>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 2, json['telecom']['rank']
    assert_equal false, json['deceasedBoolean']
  end

  def test_xml_converter_preserves_ids_and_resource_types
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <id value="patient-123"/>
        <meta>
          <profile value="http://hl7.org/fhir/StructureDefinition/Patient"/>
        </meta>
      </Patient>
    XML

    json = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal 'Patient', json['resourceType']
    assert_equal 'patient-123', json['id']
    assert_equal 'http://hl7.org/fhir/StructureDefinition/Patient', json['meta']['profile']
  end

  def test_xml_converter_returns_deterministic_output
    xml = <<~XML
      <Patient xmlns="http://hl7.org/fhir">
        <id value="test"/>
        <active value="true"/>
      </Patient>
    XML

    json1 = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)
    json2 = FHIRPath::Conformance::FHIRXmlConverter.convert(xml)

    assert_equal json1, json2
  end

  def test_fixture_resolver_finds_matching_json_for_xml_fixture
    Dir.mktmpdir('fhirpath-fixture') do |root|
      FileUtils.mkdir_p(File.join(root, 'r4', 'examples'))
      File.write(File.join(root, 'r4', 'examples', 'patient-example.xml'), <<~XML)
        <Patient xmlns="http://hl7.org/fhir">
          <id value="example"/>
          <active value="true"/>
        </Patient>
      XML
      File.write(File.join(root, 'r4', 'examples', 'patient-example.json'),
                 JSON.generate({ 'resourceType' => 'Patient', 'id' => 'example', 'active' => true }))

      resolver = FHIRPath::Conformance::FixtureResolver.new(root: root)
      result = resolver.resolve('r4/examples/patient-example.xml')

      assert_kind_of Hash, result
      assert_equal 'Patient', result['resourceType']
      assert_equal 'example', result['id']
    end
  end

  def test_fixture_resolver_rejects_same_basename_with_different_id
    Dir.mktmpdir('fhirpath-fixture') do |root|
      File.write(File.join(root, 'patient-example.xml'), <<~XML)
        <Patient xmlns="http://hl7.org/fhir">
          <id value="expected-id"/>
        </Patient>
      XML
      # Same basename, but a different resource instance (different id) must be
      # rejected structurally, not trusted because it shares the basename.
      File.write(File.join(root, 'patient-example.json'),
                 JSON.generate({ 'resourceType' => 'Patient', 'id' => 'other-id' }))

      resolver = FHIRPath::Conformance::FixtureResolver.new(root: root)
      assert_nil resolver.resolve('patient-example.xml')
    end
  end

  def test_fixture_resolver_returns_nil_when_no_matching_json
    Dir.mktmpdir('fhirpath-fixture') do |root|
      File.write(File.join(root, 'complex.xml'), <<~XML)
        <Patient xmlns="http://hl7.org/fhir">
          <active value="true"/>
        </Patient>
      XML

      resolver = FHIRPath::Conformance::FixtureResolver.new(root: root)
      result = resolver.resolve('complex.xml')

      assert_nil result
    end
  end
end
