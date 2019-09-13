//
//  Descriptor.swift
//

import Foundation

// TO DO: ScalarDescriptor.toRecord() which attempts to read descriptor data as AERecord and throws if the numbers don't add up (this is how AEM does it)

// TO DO: need an API to traverse nested descriptors in order to, e.g. print human-readable representation

// TO DO: implement Comparable

// TO DO: implement CustomStringConvertible (this should return literal representation, using unpackAsAny() to unroll lists and records; note that some Swift types, e.g. String, Date, should be shown as literal representation [even when not nested?])

public protocol Descriptor: CustomDebugStringConvertible {
    
    var type: DescType { get } // AEDesc.descriptorType
    var data: Data { get } // TO DO: make this private? (caution: this may be a slice view into a larger underlying buffer, so do not assume it starts on index 0; use data.startIndex)
    
    func flatten() -> Data
    func appendTo(containerData: inout Data)
}

public extension Descriptor {
    
    var debugDescription: String {
        return "<\(Swift.type(of: self)) \(literalFourCharCode(self.type))>"
    }
}


// object specifiers

// specifier root (wrapper), object specifier, insertion location
public protocol QueryDescriptor: Scalar {
    
    var from: QueryDescriptor { get }
    
}


// (aka 'whose' clauses) comparison descriptor, logical descriptor
public protocol TestDescriptor: Scalar {
}


// AEList/AERecord iterators are mostly used to unpack

public protocol IterableDescriptor: Descriptor, Sequence { // AEList/AERecord; not sure about AppleEvent
    
    associatedtype Element
    
    var count: UInt32 { get }
    
    // TO DO: having this method public is not ideal as it requires internal knowledge to use correctly
    func element(at offset: Int) -> (item: Element, endOffset: Int)
}



public struct DescriptorIterator<D: IterableDescriptor>: IteratorProtocol {
    
    private var count = 0
    private var offset = 0
    private var descriptor: D
    
    public typealias Element = D.Element
    
    init(_ descriptor: D) {
        self.descriptor = descriptor
        self.offset = self.descriptor.data.startIndex
    }
    
    public mutating func next() -> Element? {
        if self.count >= self.descriptor.count { return nil }
        let (result, endOffset) = self.descriptor.element(at: self.offset)
        self.count += 1
        self.offset = endOffset
        return result
    }
}
