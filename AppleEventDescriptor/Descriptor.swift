//
//  Descriptor.swift
//

import Foundation


// TO DO: need an API to traverse nested descriptors in order to, e.g. print human-readable representation


public protocol Descriptor: CustomDebugStringConvertible {
    
    var type: DescType { get } // AEDesc.descriptorType
    var data: Data { get } // TO DO: make this private?
    
    func flatten() -> Data
    func appendTo(containerData: inout Data)
    
}

public extension Descriptor {
    
    var debugDescription: String {
        return "<\(Swift.type(of: self)) \(literalFourCharCode(self.type))>"
    }
}


// object specifiers

public protocol Query: Scalar {}    // specifier root (wrapper), object specifier, insertion location

public protocol Test: Scalar {}     // (aka 'whose' clauses) comparison descriptor, logical descriptor


// AEList/AERecord iterators are mostly used to unpack

public protocol IterableDescriptor: Descriptor, Sequence { // AEList/AERecord; not sure about AppleEvent
    
    associatedtype Element
    
    var count: UInt32 { get }
    
    // TO DO: having this method public is not ideal as it requires internal knowledge to use correctly
    func element(at offset: Int) -> (item: Element, endOffset: Int)
}



public struct DescriptorIterator<D: IterableDescriptor>: IteratorProtocol {
    
    private var index = 0
    private var offset = 0
    private var descriptor: D
    
    public typealias Element = D.Element
    
    init(_ descriptor: D) {
        self.descriptor = descriptor
    }
    
    public mutating func next() -> Element? {
        if self.index >= self.descriptor.count { return nil }
        let (result, endOffset) = self.descriptor.element(at: self.offset)
        self.index += 1
        self.offset = endOffset
        return result
    }
}