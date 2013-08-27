# Copyright 2011-2013 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

require 'spec_helper'

module Aws
  module Xml
    describe Parser do

      let(:rules) {{
        'type' => 'structure',
        'members' => {},
      }}

      def parse(xml)
        shape = Seahorse::Model::Shapes::Shape.from_hash(rules)
        Parser.to_hash(shape, xml)
      end

      it 'returns an empty hash when the XML is empty' do
        expect(parse('<xml/>')).to eq({})
      end

      it 'ignores xml namespaces on the root element' do
        expect(parse('<xml xmlns="http://xmlns.com"/>')).to eq({})
      end

      it 'ignores xml elements when the rules are empty' do
        rules['members'] = {}
        expect(parse('<xml><foo>bar</foo></xml>')).to eq({})
      end

      describe 'structures' do

        it 'parses structure members' do
          rules['members'] = {
            'first' => { 'type' => 'string' },
            'last' => { 'type' => 'string' }
          }
          xml = <<-XML
            <xml>
              <first>abc</first>
              <last>xyz</last>
            </xml>
          XML
          expect(parse(xml)).to eq(first: 'abc', last: 'xyz')
        end

        it 'parses members using their serialized name' do
          rules['members'] = {
            'first' => { 'type' => 'string', 'serialized_name' => 'FirstName' },
            'last' => { 'type' => 'string', 'serialized_name' => 'LastName' }
          }
          xml = <<-XML
            <xml>
              <FirstName>John</FirstName>
              <LastName>Doe</LastName>
            </xml>
          XML
          expect(parse(xml)).to eq(first: 'John', last: 'Doe')
        end

        it 'parses structures of structures' do
          rules['members'] = {
            'config' => {
              'type' => 'structure',
              'members' => {
                'state' => { 'type' => 'string' }
              }
            },
            'name' => { 'type' => 'string' }
          }
          xml = <<-XML
            <xml>
              <config>
                <state>on</state>
              </config>
              <name>abc</name>
            </xml>
          XML
          expect(parse(xml)).to eq(config: { state: 'on' }, name: 'abc')
        end

      end

      describe 'non-flattened lists' do

        it 'returns missing lists as nil' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'members' => { 'type' => 'string' }
            }
          }
          xml = "<xml/>"
          expect(parse(xml)[:items]).to be(nil)
        end

        it 'returns empty list elements as []' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'members' => { 'type' => 'string' }
            }
          }
          xml = "<xml><items/></xml>"
          expect(parse(xml)[:items]).to eq([])
        end

        it 'converts lists of strings into arrays of strings' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'members' => { 'type' => 'string' }
            }
          }
          xml = <<-XML
            <xml>
              <items>
                <member>abc</member>
                <member>mno</member>
                <member>xyz</member>
              </items>
            </xml>
          XML
          expect(parse(xml)[:items]).to eq(%w(abc mno xyz))
        end

        it 'accepts lists of single elements' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'members' => { 'type' => 'string' }
            }
          }
          xml = <<-XML
            <xml>
              <items>
                <member>abc</member>
              </items>
            </xml>
          XML
          expect(parse(xml)[:items]).to eq(['abc'])
        end

        it 'observes the list member serialization name when present' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'members' => { 'type' => 'string', 'serialized_name' => 'item' }
            }
          }
          xml = <<-XML
            <xml>
              <items>
                <item>abc</item>
                <item>mno</item>
                <item>xyz</item>
              </items>
            </xml>
          XML
          expect(parse(xml)[:items]).to eq(%w(abc mno xyz))
        end

        it 'can parse lists of complex types' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'members' => {
                'type' => 'structure',
                'serialized_name' => 'item',
                'members' => { 'name' => { 'type' => 'string' } }
              }
            }
          }
          xml = <<-XML
            <xml>
              <items>
                <item><name>abc</name></item>
                <item><name>mno</name></item>
                <item><name>xyz</name></item>
              </items>
            </xml>
          XML
          expect(parse(xml)[:items]).to eq([
            { name: 'abc' },
            { name: 'mno' },
            { name: 'xyz' }
          ])
        end

      end

      describe 'flattened lists' do

        it 'returns missing lists as nil' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'flattened' => true,
              'members' => { 'type' => 'string' }
            }
          }
          xml = "<xml/>"
          expect(parse(xml)[:items]).to be(nil)
        end

        it 'returns empty list elements as []' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'flattened' => true,
              'members' => { 'type' => 'string' }
            }
          }
          xml = "<xml><items/></xml>"
          expect(parse(xml)[:items]).to eq([])
        end

        it 'converts lists of strings into arrays of strings' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'flattened' => true,
              'members' => { 'type' => 'string' }
            }
          }
          xml = <<-XML
            <xml>
              <items>abc</items>
              <items>mno</items>
              <items>xyz</items>
            </xml>
          XML
          expect(parse(xml)[:items]).to eq(%w(abc mno xyz))
        end

        it 'accepts lists of a single element' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'flattened' => true,
              'members' => { 'type' => 'string' }
            }
          }
          xml = <<-XML
            <xml>
              <items>abc</items>
            </xml>
          XML
          expect(parse(xml)[:items]).to eq(['abc'])
        end

        it 'observes the list serialization name when present' do
          rules['members'] = {
            'items' => {
              'type' => 'list',
              'flattened' => true,
              'serialized_name' => 'item',
              'members' => { 'type' => 'string' }
            }
          }
          xml = <<-XML
            <xml>
              <item>abc</item>
              <item>mno</item>
              <item>xyz</item>
            </xml>
          XML
          expect(parse(xml)[:items]).to eq(%w(abc mno xyz))
        end

        it 'can parse lists of complex types' do
          rules['members'] = {
            'people' => {
              'type' => 'list',
              'flattened' => true,
              'serialized_name' => 'Person',
              'members' => {
                'type' => 'structure',
                'members' => {
                  'name' => { 'type' => 'string', 'serialized_name' => 'Name' }
                }
              }
            }
          }
          xml = <<-XML
            <xml>
              <Person><Name>abc</Name></Person>
              <Person><Name>mno</Name></Person>
              <Person><Name>xyz</Name></Person>
            </xml>
          XML
          expect(parse(xml)[:people]).to eq([
            { name: 'abc' },
            { name: 'mno' },
            { name: 'xyz' }
          ])
        end

      end

      describe 'non-flattened maps' do

        it 'returns missing maps as nil' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'keys' => { 'type' => 'string' },
              'members' => { 'type' => 'string' }
            }
          }
          xml = "<xml/>"
          expect(parse(xml)[:attributes]).to be(nil)
        end

        it 'returns empty maps as {}' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'keys' => { 'type' => 'string' },
              'members' => { 'type' => 'string' }
            }
          }
          xml = "<xml><attributes/></xml>"
          expect(parse(xml)[:attributes]).to eq({})
        end

        it 'expects entry, key and value tags by default' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'keys' => { 'type' => 'string' },
              'members' => { 'type' => 'string' }
            }
          }
          xml = <<-XML
            <xml>
              <attributes>
                <entry>
                  <key>Color</key>
                  <value>red</value>
                </entry>
                <entry>
                  <key>Size</key>
                  <value>large</value>
                </entry>
              </attributes>
            </xml>
          XML
          expect(parse(xml)[:attributes]).to eq({
            'Color' => 'red',
            'Size' => 'large'
          })
        end

        it 'accepts maps with a single entry' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'keys' => { 'type' => 'string' },
              'members' => { 'type' => 'string' }
            }
          }
          xml = <<-XML
            <xml>
              <attributes>
                <entry>
                  <key>Color</key>
                  <value>red</value>
                </entry>
              </attributes>
            </xml>
          XML
          expect(parse(xml)[:attributes]).to eq('Color' => 'red')
        end

        it 'accepts alternate key and value names' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'keys' => { 'type' => 'string', 'serialized_name' => 'attr' },
              'members' => { 'type' => 'string', 'serialized_name' => 'val' }
            }
          }
          xml = <<-XML
            <xml>
              <attributes>
                <entry>
                  <attr>hue</attr>
                  <val>red</val>
                </entry>
                <entry>
                  <attr>size</attr>
                  <val>med</val>
                </entry>
              </attributes>
            </xml>
          XML
          expect(parse(xml)[:attributes]).to eq('hue' => 'red', 'size' => 'med')
        end

      end

      describe 'flattened maps' do

        it 'returns missing maps as nil' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'flattened' => true,
              'keys' => { 'type' => 'string' },
              'members' => { 'type' => 'string' }
            }
          }
          xml = "<xml/>"
          expect(parse(xml)[:attributes]).to be(nil)
        end

        it 'returns empty maps as {}' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'flattened' => true,
              'keys' => { 'type' => 'string' },
              'members' => { 'type' => 'string' }
            }
          }
          xml = "<xml><attributes/></xml>"
          expect(parse(xml)[:attributes]).to eq({})
        end

        it 'expects key and value tags by default' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'flattened' => true,
              'keys' => { 'type' => 'string' },
              'members' => { 'type' => 'string' }
            }
          }
          xml = <<-XML
            <xml>
              <attributes>
                <key>Color</key>
                <value>red</value>
              </attributes>
              <attributes>
                <key>Size</key>
                <value>large</value>
              </attributes>
            </xml>
          XML
          expect(parse(xml)[:attributes]).to eq({
            'Color' => 'red',
            'Size' => 'large'
          })
        end

        it 'accepts maps with a single entry' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'flattened' => true,
              'keys' => { 'type' => 'string' },
              'members' => { 'type' => 'string' }
            }
          }
          xml = <<-XML
            <xml>
              <attributes>
                <key>Color</key>
                <value>red</value>
              </attributes>
            </xml>
          XML
          expect(parse(xml)[:attributes]).to eq('Color' => 'red')
        end

        it 'accepts alternate key and value names' do
          rules['members'] = {
            'attributes' => {
              'type' => 'map',
              'flattened' => true,
              'keys' => { 'type' => 'string', 'serialized_name' => 'attr' },
              'members' => { 'type' => 'string', 'serialized_name' => 'val' }
            }
          }
          xml = <<-XML
            <xml>
              <attributes>
                <attr>hue</attr>
                <val>red</val>
              </attributes>
              <attributes>
                <attr>size</attr>
                <val>med</val>
              </attributes>
            </xml>
          XML
          expect(parse(xml)[:attributes]).to eq('hue' => 'red', 'size' => 'med')
        end

      end

      describe 'booleans' do

        before(:each) do
          rules['members'] = { 'enabled' => { 'type' => 'boolean' } }
        end

        it 'converts boolean true values' do
          xml = "<xml><enabled>true</enabled></xml>"
          expect(data(xml)).to eq(enabled: true)
        end

        it 'converts boolean false values' do
          xml = "<xml><enabled>false</enabled></xml>"
          expect(data(xml)).to eq(enabled: false)
        end

        it 'does not apply a boolean true/false value when not present' do
          xml = "<xml/>"
          expect(data(xml)).to eq({})
        end

      end

      describe 'timestamps' do
      end

      describe 'integers' do
      end

      describe 'floats' do
      end

      describe 'xmlnames' do
      end

      describe 'blobs' do
      end

      describe 'xml namespaces' do
      end

      describe 'parsing errors' do
      end

    end
  end
end
