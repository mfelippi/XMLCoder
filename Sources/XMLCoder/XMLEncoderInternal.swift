//
//  XMLEncoderInternal.swift
//  XMLCoder
//
//  Created by Frank on 23/08/2018.
//  Copyright © 2018 Frank Lefebvre. All rights reserved.
//

import Foundation

class _XMLEncoder: Encoder {
    
    init(options: XMLEncoder._Options, namespaceProvider: XMLNamespaceProvider) {
        self.options = options
        self.namespaceProvider = namespaceProvider
    }
    
    let options: XMLEncoder._Options
    let namespaceProvider: XMLNamespaceProvider
    
    lazy var floatFormatter = newDecimalFormatter(16)
    lazy var doubleFormatter = newDecimalFormatter(128)
    lazy var dateFormatter = newDateFormatter()
    
    private func newDecimalFormatter(_ precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = precision
        return formatter
    }
    
    private func newDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:SS'Z'"
        return formatter
    }
    
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    func topElement(withName name: String) -> XMLElement {
        return XMLNode.element(withName: name, children: topElements?.nodes ?? [], attributes: topElements?.attributes ?? []) as! XMLElement
    }
    
    var topElements: XMLEncodingStorage?
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        if topElements == nil {
            topElements = KeyedXMLElementStorage()
        }
        return KeyedEncodingContainer(XMLKeyedEncodingContainer(referencing: self, codingPath: codingPath, wrapping: topElements as! KeyedXMLElementStorage))
    }
    
    struct XMLKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        // MARK: Properties
        
        /// A reference to the encoder we're writing to.
        private let encoder: _XMLEncoder
        
        /// A reference to the storage we're writing to.
        private var storage: KeyedXMLElementStorage
        
        /// The path of coding keys taken to get to this point in encoding.
        private(set) public var codingPath: [CodingKey]
        
        // MARK: - Initialization
        
        /// Initializes `self` with the given references.
        fileprivate init(referencing encoder: _XMLEncoder, codingPath: [CodingKey], wrapping storage: KeyedXMLElementStorage) {
            self.encoder = encoder
            self.codingPath = codingPath
            self.storage = storage
        }
        
        // MARK: - Coding Path Operations
        
        private func _converted(_ key: CodingKey) -> String {
            if let qualkey = key as? XMLQualifiedKey, let namespace = qualkey.namespace {
                if let name = encoder.namespaceProvider.name(for: namespace) {
                    // For now we'll move all namespace declarations up to the root level.
                    // TODO: add namespace URI to current storage, unless already declared in hierarchy.
                    return "\(name):\(key.stringValue)"
                }
            }
            return key.stringValue
            
            #if false
            switch encoder.options.keyEncodingStrategy {
            case .useDefaultKeys:
                return key
            case .convertToSnakeCase:
                let newKeyString = XMLEncoder.KeyEncodingStrategy._convertToSnakeCase(key.stringValue)
                return _XMLKey(stringValue: newKeyString, intValue: key.intValue)
            case .custom(let converter):
                return converter(codingPath + [key])
            }
            #endif
        }        
        
        mutating func encodeNil(forKey key: Key) throws {
            if encoder.options.nilEncodingStrategy == .empty {
                try encode("", forKey: key)
            }
        }
        
        mutating func encode(_ value: Bool, forKey key: Key) throws {
            try encode(encoder.converted(value), forKey: key)
        }
        
        mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            if let attribute = value as? CodableXMLAttribute {
                let attributeNode = XMLNode.attribute(withName: _converted(key), stringValue: attribute.value) as! XMLNode
                self.storage.attributes.append(attributeNode)
                return
            }
            if let inlineText = value as? CodableXMLInlineText {
                let textNode = XMLNode.text(withStringValue: inlineText.value) as! XMLNode
                self.storage.nodes.append(textNode)
                return
            }
            let childEncoder = _XMLEncoder(options: encoder.options, namespaceProvider: encoder.namespaceProvider)
            if let string = try encoder.converted(value: value) {
                try string.encode(to: childEncoder)
            }
            else {
                try value.encode(to: childEncoder)
            }
            guard let children = childEncoder.topElements else {
                return
            }
            if children.nodes.isEmpty && children.attributes.isEmpty {
                return
            }
            let valueIsOptionalAttribute = T.self == Optional<CodableXMLAttribute>.self
            if valueIsOptionalAttribute, let attributeString = children.nodes.first?.stringValue {
                let attributeNode = XMLNode.attribute(withName: _converted(key), stringValue: attributeString) as! XMLNode
                self.storage.attributes.append(attributeNode)
                return
            }
            let element = XMLNode.element(withName:_converted(key), children: children.nodes, attributes: children.attributes) as! XMLElement // box(value)
            self.storage.nodes.append(element)
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError()
        }
        
        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            fatalError()
        }
        
        mutating func superEncoder() -> Encoder {
            fatalError()
        }
        
        mutating func superEncoder(forKey key: Key) -> Encoder {
            fatalError()
        }
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if topElements == nil {
            topElements = UnkeyedXMLElementStorage()
        }
        return XMLUnkeyedEncodingContainer(referencing: self, codingPath: codingPath, wrapping: topElements as! UnkeyedXMLElementStorage)
    }
    
    struct XMLUnkeyedEncodingContainer: UnkeyedEncodingContainer {
        
        // MARK: Properties
        
        /// A reference to the encoder we're writing to.
        private let encoder: _XMLEncoder
        
        /// A reference to the storage we're writing to.
        private var storage: UnkeyedXMLElementStorage
        
        /// The path of coding keys taken to get to this point in encoding.
        private(set) public var codingPath: [CodingKey]
        
        var count: Int { get { return storage.nodes.count }}
        
        // MARK: - Initialization
        
        /// Initializes `self` with the given references.
        fileprivate init(referencing encoder: _XMLEncoder, codingPath: [CodingKey], wrapping storage: UnkeyedXMLElementStorage) {
            self.encoder = encoder
            self.codingPath = codingPath
            self.storage = storage
        }
        
        mutating func encodeNil() throws {
            if encoder.options.nilEncodingStrategy == .empty {
                try encode("")
            }
        }
        
        mutating func encode(_ value: Bool) throws {
            try encode(encoder.converted(value))
        }
        
        mutating func encode<T>(_ value: T) throws where T : Encodable {
            let childEncoder = _XMLEncoder(options: encoder.options, namespaceProvider: encoder.namespaceProvider)
            var elementMode: XMLElementMode?
            if let string = try encoder.converted(value: value) {
                try string.encode(to: childEncoder)
                elementMode = string.elementMode
            }
            else {
                try value.encode(to: childEncoder)
                if let value = value as? XMLCustomElementMode {
                    elementMode = value.elementMode
                }
            }
            guard let childStorage = childEncoder.topElements else {
                fatalError("Storage wasn't created after successful encoding.")
            }
            if elementMode == nil {
                elementMode = childStorage.elementMode
            }
            switch elementMode! {
            case .inline:
                for element in childStorage.nodes {
                    self.storage.nodes.append(element)
                }
            case .keyed(let elementName):
                let element = XMLNode.element(withName:elementName, children: childStorage.nodes, attributes: childStorage.attributes) as! XMLElement // box(value)
                self.storage.nodes.append(element)
            }
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError()
        }
        
        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            fatalError()
        }
        
        mutating func superEncoder() -> Encoder {
            fatalError()
        }
        
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        if topElements == nil {
            topElements = SingleXMLElementStorage()
        }
        else {
            fatalError()
        }
        return XMLSingleValueEncodingContainer(referencing: self, codingPath: codingPath, wrapping: topElements as! SingleXMLElementStorage)
    }
    
    struct XMLSingleValueEncodingContainer: SingleValueEncodingContainer {
        
        // MARK: Properties
        
        /// A reference to the encoder we're writing to.
        private let encoder: _XMLEncoder
        
        /// A reference to the storage we're writing to.
        private var storage: SingleXMLElementStorage
        
        /// The path of coding keys taken to get to this point in encoding.
        private(set) public var codingPath: [CodingKey]
        
        // MARK: - Initialization
        
        /// Initializes `self` with the given references.
        fileprivate init(referencing encoder: _XMLEncoder, codingPath: [CodingKey], wrapping storage: SingleXMLElementStorage) {
            self.encoder = encoder
            self.codingPath = codingPath
            self.storage = storage
        }
        
        mutating func encodeNil() throws {
            if encoder.options.nilEncodingStrategy == .empty {
                try encode("")
            }
        }
        
        mutating func encode(_ value: Bool) throws {
            try encode(encoder.converted(value))
        }
        
        mutating func encode(_ value: String) throws {
            let element = XMLNode.text(withStringValue:value) as! XMLNode // box(value)
            self.storage.nodes.append(element)
        }
        
        mutating func encode(_ value: Double) throws {
            guard let formattedValue = encoder.doubleFormatter.string(for: value) else {
                return
            }
            try encode(formattedValue)
        }
        
        mutating func encode(_ value: Float) throws {
            guard let formattedValue = encoder.floatFormatter.string(for: value) else {
                return
            }
            try encode(formattedValue)
        }
        
        mutating func encode(_ value: Int) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: Int8) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: Int16) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: Int32) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: Int64) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: UInt) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: UInt8) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: UInt16) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: UInt32) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: UInt64) throws {
            try encode(String(value))
        }
        
        mutating func encode<T>(_ value: T) throws where T : Encodable {
            fatalError()
        }
    }
    
    private func converted<T>(value: T) throws -> XMLStringElement? where T : Encodable {
        if T.self == Date.self {
            return try converted(value as! Date)
        }
        else if T.self == URL.self {
            return converted(value as! URL)
        }
        else if T.self == Data.self {
            return converted(value as! Data)
        }
        else if T.self == Bool.self {
            return converted(value as! Bool)
        }
        else {
            return nil
        }
    }
    
    private func converted(_ date: Date) throws -> XMLStringElement {
        return dateFormatter.string(from: date) // TODO: use DateEncodingStrategy
    }
    
    private func converted(_ url: URL) -> XMLStringElement {
        return url.absoluteString
    }
    
    private func converted(_ data: Data) -> XMLStringElement {
        return data.base64EncodedString() // TODO: use DataEncodingStrategy
    }
    
    private func converted(_ bool: Bool) -> XMLStringElement {
        return bool ? options.boolEncodingStrategy.trueValue : options.boolEncodingStrategy.falseValue
    }
}