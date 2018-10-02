//
//  _XMLEncoder.swift
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
    
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    func topElement(withName name: String) -> XMLElement {
        return XMLNode.element(withName: name, children: topElements?.nodes ?? [], attributes: topElements?.attributes ?? []) as! XMLElement
    }
    
    var topElements: XMLEncodingContainer?
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        if topElements == nil {
            topElements = KeyedXMLElementContainer()
        }
        return KeyedEncodingContainer(XMLKeyedEncodingContainer(referencing: self, codingPath: codingPath, wrapping: topElements as! KeyedXMLElementContainer))
    }
    
    struct XMLKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        // MARK: Properties
        
        /// A reference to the encoder we're writing to.
        private let encoder: _XMLEncoder
        
        /// A reference to the container we're writing to.
        private var container: KeyedXMLElementContainer
        
        /// The path of coding keys taken to get to this point in encoding.
        private(set) public var codingPath: [CodingKey]
        
        // MARK: - Initialization
        
        /// Initializes `self` with the given references.
        fileprivate init(referencing encoder: _XMLEncoder, codingPath: [CodingKey], wrapping container: KeyedXMLElementContainer) {
            self.encoder = encoder
            self.codingPath = codingPath
            self.container = container
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
            fatalError()
        }
        
        mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            if let attribute = value as? CodableXMLAttribute {
                let attributeNode = XMLNode.attribute(withName: _converted(key), stringValue: attribute.value) as! XMLNode
                self.container.attributes.append(attributeNode)
                return
            }
            if let inlineText = value as? CodableXMLInlineText {
                let textNode = XMLNode.text(withStringValue: inlineText.value) as! XMLNode
                self.container.nodes.append(textNode)
                return
            }
            let childEncoder = _XMLEncoder(options: encoder.options, namespaceProvider: encoder.namespaceProvider)
            try value.encode(to: childEncoder)
            guard let children = childEncoder.topElements else {
                return
            }
            if children.nodes.isEmpty && children.attributes.isEmpty {
                return
            }
            let valueIsOptionalAttribute = T.self == Optional<CodableXMLAttribute>.self
            if valueIsOptionalAttribute, let attributeString = children.nodes.first?.stringValue {
                let attributeNode = XMLNode.attribute(withName: _converted(key), stringValue: attributeString) as! XMLNode
                self.container.attributes.append(attributeNode)
                return
            }
            let element = XMLNode.element(withName:_converted(key), children: children.nodes, attributes: children.attributes) as! XMLElement // box(value)
            self.container.nodes.append(element)
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
            topElements = UnkeyedXMLElementContainer()
        }
        return XMLUnkeyedEncodingContainer(referencing: self, codingPath: codingPath, wrapping: topElements as! UnkeyedXMLElementContainer)
    }
    
    struct XMLUnkeyedEncodingContainer: UnkeyedEncodingContainer {
        
        // MARK: Properties
        
        /// A reference to the encoder we're writing to.
        private let encoder: _XMLEncoder
        
        /// A reference to the container we're writing to.
        private var container: UnkeyedXMLElementContainer
        
        /// The path of coding keys taken to get to this point in encoding.
        private(set) public var codingPath: [CodingKey]
        
        var count: Int { get { return container.nodes.count }}
        
        // MARK: - Initialization
        
        /// Initializes `self` with the given references.
        fileprivate init(referencing encoder: _XMLEncoder, codingPath: [CodingKey], wrapping container: UnkeyedXMLElementContainer) {
            self.encoder = encoder
            self.codingPath = codingPath
            self.container = container
        }
        
        mutating func encodeNil() throws {
            if encoder.options.nilEncodingStrategy == .empty {
                try encode("")
            }
        }
        
        mutating func encode(_ value: Bool) throws {
            fatalError()
        }
        
        mutating func encode<T>(_ value: T) throws where T : Encodable {
            let childEncoder = _XMLEncoder(options: encoder.options, namespaceProvider: encoder.namespaceProvider)
            try value.encode(to: childEncoder)
            guard let childContainer = childEncoder.topElements else {
                fatalError("Container wasn't created after successful encoding.")
            }
            let elementMode: XMLElementMode
            if let value = value as? XMLCustomElementMode {
                elementMode = value.elementMode
            }
            else {
                elementMode = childContainer.elementMode
            }
            switch elementMode {
            case .inline:
                for element in childContainer.nodes {
                    self.container.nodes.append(element)
                }
            case .keyed(let elementName):
                let element = XMLNode.element(withName:elementName, children: childContainer.nodes, attributes: childContainer.attributes) as! XMLElement // box(value)
                self.container.nodes.append(element)
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
            topElements = SingleXMLElementContainer()
        }
        else {
            fatalError()
        }
        return XMLSingleValueEncodingContainer(referencing: self, codingPath: codingPath, wrapping: topElements as! SingleXMLElementContainer)
    }
    
    struct XMLSingleValueEncodingContainer: SingleValueEncodingContainer {
        
        // MARK: Properties
        
        /// A reference to the encoder we're writing to.
        private let encoder: _XMLEncoder
        
        /// A reference to the container we're writing to.
        private var container: SingleXMLElementContainer
        
        /// The path of coding keys taken to get to this point in encoding.
        private(set) public var codingPath: [CodingKey]
        
        // MARK: - Initialization
        
        /// Initializes `self` with the given references.
        fileprivate init(referencing encoder: _XMLEncoder, codingPath: [CodingKey], wrapping container: SingleXMLElementContainer) {
            self.encoder = encoder
            self.codingPath = codingPath
            self.container = container
        }
        
        mutating func encodeNil() throws {
            if encoder.options.nilEncodingStrategy == .empty {
                try encode("")
            }
        }
        
        mutating func encode(_ value: Bool) throws {
            fatalError()
        }
        
        mutating func encode(_ value: String) throws {
            let element = XMLNode.text(withStringValue:value) as! XMLNode // box(value)
            self.container.nodes.append(element)
        }
        
        mutating func encode(_ value: Date) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Double) throws {
            try encode(String(value))
        }
        
        mutating func encode(_ value: Float) throws {
            fatalError()
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
}
