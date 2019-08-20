import XCTest
@testable import XMLCoder

final class XMLEncoderTests: XCTestCase {
    func testEncodeBasicXML() {
		let embedded = BasicEmbeddedStruct(some_element: "inside")
		let value = BasicTestStruct(integer_element: 42, string_element: "   moof   & < >   ", embedded_element: embedded, string_array: ["one", "two", "three"], int_array: [1, 2, 3])

		let result = Test.xmlString(value)
		
        let expected = """
        <root>\
        <integer_element>42</integer_element>\
        <string_element>   moof   &amp; &lt; &gt;   </string_element>\
        <embedded_element><some_element>inside</some_element></embedded_element>\
        <string_array><element>one</element><element>two</element><element>three</element></string_array>\
        <int_array><element>1</element><element>2</element><element>3</element></int_array>\
        </root>
        """
        
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    func testAttributes() {
        let contents = AttributesStruct(element: "elem", attribute: "attr", inlineText: "text", number: 42)
        let value = AttributesEnclosingStruct(container: contents, top_attribute: "top")
        
        let result = Test.xmlString(value)
        
        let expected = """
        <root top_attribute="top"><container attribute="attr"><element>elem</element>text<number>42</number></container></root>
        """
        
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
        
        let jsonResult = Test.jsonString(value)
        let jsonExpected = """
        {"container":{"attribute":"attr","element":"elem","inlineText":"text","number":42},"top_attribute":"top"}
        """
        XCTAssertEqual(jsonResult, jsonExpected)
    }
    
    func testNamespaces() {
        let value = NamespaceStruct(with_namespace: "test1", without_namespace: "test2")
        
        let result = Test.xmlString(value)
        
        let expected = """
        <root xmlns:ns1="http://some.url.example.com/whatever">\
        <ns1:with_namespace>test1</ns1:with_namespace>\
        <without_namespace>test2</without_namespace>\
        </root>
        """
        
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
        
        let jsonResult = Test.jsonString(value)
        let jsonExpected = """
        {"with_namespace":"test1","without_namespace":"test2"}
        """
        XCTAssertEqual(jsonResult, jsonExpected)
    }
    
    func testNamespacesWithOptions() {
        let value = NamespaceStruct(with_namespace: "test1", without_namespace: "test2")
        let encoder = XMLEncoder()
        encoder.defaultNamespace = "http://some.url.example.com/default"
        encoder.namespacePrefix = "nsns"
        let xml = try! encoder.encode(value)
        let result = String(data: xml.xmlData, encoding: .utf8)
        
        let expected = """
        <root xmlns="http://some.url.example.com/default" xmlns:nsns1="http://some.url.example.com/whatever">\
        <nsns1:with_namespace>test1</nsns1:with_namespace>\
        <without_namespace>test2</without_namespace>\
        </root>
        """
        
        XCTAssertEqual(result?.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
        
        let jsonResult = Test.jsonString(value)
        let jsonExpected = """
        {"with_namespace":"test1","without_namespace":"test2"}
        """
        XCTAssertEqual(jsonResult, jsonExpected)
    }
    
    func testArrayWithKeyedStringElements() {
        let value = ArrayStruct(string: "some text", children: ["one", "two", "three", "four"])
        
        let result = Test.xmlString(value)
        
        let expected = """
        <root>\
        <string>some text</string>\
        <children><child>one</child><child>two</child><child>three</child><child>four</child></children>\
        </root>
        """
        
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
        
        let jsonResult = Test.jsonString(value)
        let jsonExpected = """
        {"children":["one","two","three","four"],"string":"some text"}
        """
        XCTAssertEqual(jsonResult, jsonExpected)
    }
    
    func testArrayWithAttributes() {
        struct ArrayElementStruct: Encodable {
            var id: String
            var inlineText: String
            
            private enum CodingKeys: String, CodingKey, XMLTypedKey {
                case id
                case inlineText
                
                var nodeType: XMLNodeType {
                    switch self {
                    case .id:
                        return .attribute
                    case .inlineText:
                        return .inline
                    }
                }
            }
        }
        
        let value = [
            ArrayElementStruct(id: "1", inlineText: "one"),
            ArrayElementStruct(id: "2", inlineText: "two"),
            ArrayElementStruct(id: "3", inlineText: "three"),
            ArrayElementStruct(id: "4", inlineText: "four"),
        ]
        
        let result = Test.xmlString(value)
        
        let expected = """
        <root>\
        <element id="1">one</element>\
        <element id="2">two</element>\
        <element id="3">three</element>\
        <element id="4">four</element>\
        </root>
        """
        
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
        
        let jsonResult = Test.jsonString(value)
        let jsonExpected = """
        [{"id":"1","inlineText":"one"},\
        {"id":"2","inlineText":"two"},\
        {"id":"3","inlineText":"three"},\
        {"id":"4","inlineText":"four"}]
        """
        XCTAssertEqual(jsonResult, jsonExpected)
    }
    
    func testArrayWithAlternatingKeysAndValues() {
        struct KeyElement: Encodable {
            let value: String
            private enum CodingKeys: String, CodingKey, XMLTypedKey {
                case value
                var nodeType: XMLNodeType {
                    return .inline
                }
            }
        }
        struct ValueElement: Encodable {
            let type: String
            let value: String
            private enum CodingKeys: String, CodingKey, XMLTypedKey {
                case type
                case value
                var nodeType: XMLNodeType {
                    switch self {
                    case .type:
                        return .attribute
                    case .value:
                        return .inline
                    }
                }
            }
        }
        struct ArrayElement: Encodable {
            let key: KeyElement
            let value: ValueElement
        }
        struct Root: Encodable { // TODO: conform encoder root to TypedKey, so that Root can be defined as [ArrayElement]
            let array: [ArrayElement]
            private enum CodingKeys: String, CodingKey, XMLTypedKey {
                case array
                var nodeType: XMLNodeType {
                    return .array(nil)
                }
            }
        }
        
        let value = Root(array: [
            ArrayElement(key: KeyElement(value: "one"), value: ValueElement(type: "string", value: "value 1")),
            ArrayElement(key: KeyElement(value: "two"), value: ValueElement(type: "integer", value: "2")),
        ])
        
        let result = Test.xmlString(value)
        
        let expected = """
        <root><array>\
        <key>one</key>\
        <value type="string">value 1</value>\
        <key>two</key>\
        <value type="integer">2</value>\
        </array></root>
        """
        
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    func testArrayOfStructs() {
        struct ArrayElement: Encodable {
            let field1: String
            let field2: String
        }
        
        let value = [
            ArrayElement(field1: "first.1", field2: "first.2"),
            ArrayElement(field1: "second.1", field2: "second.2"),
            ArrayElement(field1: "third.1", field2: "third.2"),
            ]
        
        let result = Test.xmlString(value)
        
        let expected = """
        <root>\
        <element><field1>first.1</field1><field2>first.2</field2></element>\
        <element><field1>second.1</field1><field2>second.2</field2></element>\
        <element><field1>third.1</field1><field2>third.2</field2></element>\
        </root>
        """
        
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
        
        let jsonResult = Test.jsonString(value)
        let jsonExpected = """
        [{"field1":"first.1","field2":"first.2"},\
        {"field1":"second.1","field2":"second.2"},\
        {"field1":"third.1","field2":"third.2"}]
        """
        XCTAssertEqual(jsonResult, jsonExpected)
    }
    
    func testArrayOfArrays() {
        let value: [[String]] = [
            ["11", "12", "13"],
            ["21", "22", "23"],
            ["31", "32", "33"],
            ["42"],
        ]
        
        let result = Test.xmlString(value)
        
        let expected = """
        <root>\
        <element><element>11</element><element>12</element><element>13</element></element>\
        <element><element>21</element><element>22</element><element>23</element></element>\
        <element><element>31</element><element>32</element><element>33</element></element>\
        <element><element>42</element></element>\
        </root>
        """
        
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
        
        let jsonResult = Test.jsonString(value)
        let jsonExpected = """
        [["11","12","13"],\
        ["21","22","23"],\
        ["31","32","33"],\
        ["42"]]
        """
        XCTAssertEqual(jsonResult, jsonExpected)
    }
    
    func testNilAsMissing() {
        struct OptionalStruct: Encodable { // TODO: factorize this struct
            var optionalAttribute: String?
            var mandatoryAttribute: String
            var optionalElement: String?
            var mandatoryElement: String
            
            enum CodingKeys: CodingKey, XMLTypedKey {
                case optionalAttribute
                case mandatoryAttribute
                case optionalElement
                case mandatoryElement
                
                var nodeType: XMLNodeType {
                    switch self {
                    case .optionalAttribute, .mandatoryAttribute:
                        return .attribute
                    default:
                        return .element
                    }
                }
            }
        }
        
        let value = OptionalStruct(optionalAttribute: nil, mandatoryAttribute: "attr", optionalElement: nil, mandatoryElement: "elem")
        
        let result = Test.xmlString(value)
        
        let expected = """
        <root mandatoryAttribute="attr">\
        <mandatoryElement>elem</mandatoryElement>\
        </root>
        """
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    func testNilAsEmpty() {
        struct OptionalStruct: Encodable {
            var optionalAttribute: String?
            var mandatoryAttribute: String
            var optionalElement: String?
            var mandatoryElement: String
            
            enum CodingKeys: CodingKey, XMLTypedKey {
                case optionalAttribute
                case mandatoryAttribute
                case optionalElement
                case mandatoryElement
                
                var nodeType: XMLNodeType {
                    switch self {
                    case .optionalAttribute, .mandatoryAttribute:
                        return .attribute
                    default:
                        return .element
                    }
                }
            }
        }
        
        let value = OptionalStruct(optionalAttribute: nil, mandatoryAttribute: "attr", optionalElement: nil, mandatoryElement: "elem")
        
        let encoder = XMLEncoder()
        encoder.nilEncodingStrategy = .empty
        let xml = try! encoder.encode(value)
        let result = String(data: xml.xmlData, encoding: .utf8)!
        
        let expected = """
        <root optionalAttribute="" mandatoryAttribute="attr">\
        <optionalElement></optionalElement>\
        <mandatoryElement>elem</mandatoryElement>\
        </root>
        """
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    func testFloatAndDouble() {
        struct FloatDoubleStruct: Encodable {
            var f: Float
            var d: Double
        }
        
        let value = FloatDoubleStruct(f: 1e-10, d: 1e-15)
        
        let result = Test.xmlString(value)
        let expected = """
        <root>\
        <f>0.0000000001</f>\
        <d>0.000000000000001</d>\
        </root>
        """
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    func testDateAndURL() {
        struct DateURLStruct: Encodable {
            var date: Date
            var dates: [Date]
            var url: URL
            var urls: [URL]
        }
        
        let date = Date(timeIntervalSince1970: 1)
        let url = URL(string: "https://swift.org/")!
        let value = DateURLStruct(date: date, dates: [date, date], url: url, urls: [url, url])
        
        let result = Test.xmlString(value)
        
        let expected = """
        <root>\
        <date>1970-01-01T00:00:00Z</date>\
        <dates><element>1970-01-01T00:00:00Z</element><element>1970-01-01T00:00:00Z</element></dates>\
        <url>https://swift.org/</url>\
        <urls><element>https://swift.org/</element><element>https://swift.org/</element></urls>\
        </root>
        """
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    func testBoolWithDefaultStrategy() {
        struct BoolStruct: Encodable {
            var test: Bool
            var tests: [Bool]
        }
        
        let value = BoolStruct(test: true, tests: [false, true, false])
        
        let result = Test.xmlString(value)
        let expected = """
        <root>\
        <test>1</test>\
        <tests><element>0</element><element>1</element><element>0</element></tests>\
        </root>
        """
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    func testBoolWithCustomStrategy() {
        struct BoolStruct: Encodable {
            var test: Bool
            var tests: [Bool]
        }
        
        let value = BoolStruct(test: true, tests: [false, true, false])
        
        let encoder = XMLEncoder()
        encoder.boolEncodingStrategy = XMLEncoder.BoolEncodingStrategy(falseValue: "no", trueValue: "yes")
        let xml = try! encoder.encode(value)
        let result = String(data: xml.xmlData, encoding: .utf8)!
        
        let expected = """
        <root>\
        <test>yes</test>\
        <tests><element>no</element><element>yes</element><element>no</element></tests>\
        </root>
        """
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    func testData() {
        struct DataStruct: Encodable {
            var element: Data
            var elements: [Data]
        }
        
        let data = Data(bytes: [0x42, 0x00, 0xff])
        let value = DataStruct(element: data, elements: [data, data])
        
        let result = Test.xmlString(value)
        let expected = """
        <root>\
        <element>QgD/</element>\
        <elements><element>QgD/</element><element>QgD/</element></elements>\
        </root>
        """
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    func testSubclass() {
        class Base: Encodable {
            var base: String = ""
        }
        class Subclass: Base {
            var sub: String = ""
            private enum CodingKeys: String, CodingKey {
                case sub
            }
            override func encode(to encoder: Encoder) throws {
                try super.encode(to: encoder)
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(sub, forKey: .sub)
            }
        }
        
        let value = Subclass()
        value.base = "base"
        value.sub = "sub"
        
        let result = Test.xmlString(value)
        let expected = """
        <root>\
        <base>base</base>\
        <sub>sub</sub>\
        </root>
        """
        XCTAssertEqual(result.substringWithXMLTag("root"), expected.substringWithXMLTag("root"))
    }
    
    static var allTests = [
        ("testEncodeBasicXML", testEncodeBasicXML),
        ("testAttributes", testAttributes),
        ("testNamespaces", testNamespaces),
        ("testNamespacesWithOptions", testNamespacesWithOptions),
        ("testArrayWithKeyedStringElements", testArrayWithKeyedStringElements),
        ("testArrayWithAttributes", testArrayWithAttributes),
        ("testArrayWithAlternatingKeysAndValues", testArrayWithAlternatingKeysAndValues),
        ("testArrayOfStructs", testArrayOfStructs),
        ("testArrayOfArrays", testArrayOfArrays),
        ("testNilAsMissing", testNilAsMissing),
        ("testNilAsEmpty", testNilAsEmpty),
        ("testFloatAndDouble", testFloatAndDouble),
        ("testDateAndURL", testDateAndURL),
        ("testBoolWithDefaultStrategy", testBoolWithDefaultStrategy),
        ("testBoolWithCustomStrategy", testBoolWithCustomStrategy),
        ("testData", testData),
        ("testSubclass", testSubclass),
    ]
}
