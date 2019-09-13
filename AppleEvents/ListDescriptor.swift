//
//  ListDescriptor.swift
//

import Foundation


public struct ListDescriptor: IterableDescriptor {
    
    public var debugDescription: String {
        return "<\(Swift.type(of: self)) [\(self.map{ $0.debugDescription }.joined(separator: ", "))]>"
    }
    
    public typealias Element = Descriptor
    public typealias Iterator = DescriptorIterator<ListDescriptor>
    
    public let type: DescType = typeAEList
    public let count: UInt32
    public let data: Data // whereas AEGetDescData() returns a complete flattened list/record (dle2), `data` only contains payload (in this case, list items); use flatten()/appendTo() to get complete list data // note: client code may wish to define its own list unpacking routines, e.g. Point/Rectangle may be quicker parsing list themselves rather than unpacking as [Int] and converting from that, particularly when supporting legacy QD struct representations as well)
    
    public init(count: UInt32, data: Data) { // also called by unflattenFirstDescriptor
        self.count = count
        self.data = data
    }
    
    // iteration
    
    public __consuming func makeIterator() -> Iterator {
        return Iterator(self)
    }
    
    public func element(at offset: Int) -> (item: Element, endOffset: Int) { // TO DO: type offsets as Data.Index, not Int
        assert(offset >= self.data.startIndex && offset < self.data.endIndex)
        return unflattenFirstDescriptor(in: self.data, startingAt: offset) as (Element, Int)
    }
    
    // serialize
    
    public func flatten() -> Data {
        var result = Data([0x64, 0x6c, 0x65, 0x32,  // format 'dle2'
                           0, 0, 0, 0,              // align
                           0x6C, 0x69, 0x73, 0x74,  // type is always 'list'
                           0, 0, 0, 0,              // [12..<16] remaining bytes (TBC)
                           0, 0, 0, 0,              // reserved?
                           0, 0, 0, 0,              // align?
                           0x00, 0x00, 0x00, 0x18,  // reserved?
                           0x6C, 0x69, 0x73, 0x74]) // type is always 'list' (repeats 8..<12)
        result += encodeUInt32(self.count)          // number of items
        result += Data([0, 0, 0, 0])                // align
        result += self.data                         // items
        result[(result.startIndex + 12)..<(result.startIndex + 16)] = encodeUInt32(UInt32(result.count - 16)) // set remaining bytes
        return result
    }
    
    public func appendTo(containerData result: inout Data) {
        result += Data([0x6C, 0x69, 0x73, 0x74])             // type is always 'list'
        result += encodeUInt32(UInt32(self.data.count + 8))  // remaining bytes
        result += encodeUInt32(self.count)                   // number of items
        result += Data([0, 0, 0, 0])                         // align
        result += self.data                                  // items
    }
}


extension ListDescriptor {
    
    // TO DO: rename pack/unpack?
    
    // TO DO: should error messages describe list position as 0-index or 1-index? (currently uses 0-index)
    
    init<S: Sequence>(from items: S, using packFunc: (S.Element) throws -> Descriptor) rethrows { // called by packAsArray
        var result = Data()
        var count: UInt32 = 0
        for value in items {
            do {
                try packFunc(value).appendTo(containerData: &result)
                count += 1
            } catch {
                throw AppleEventError(message: "Can't pack item \(count) of list.", cause: error)
            }
        }
        self.init(count: count, data: result)
    }
    
    
    func array<T>(using unpackFunc: (Descriptor) throws -> T) rethrows -> [T] { // called by unpackAsArray // Q. throws vs rethrows?
        var result = [T]()
        for (count, descriptor) in self.enumerated() {
            do {
                result.append(try unpackFunc(descriptor))
            } catch {
                throw AppleEventError(message: "Can't unpack item \(count) of list.", cause: error)
            }
        }
        return result
    }    
}

