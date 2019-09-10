//
//  RecordDescriptor.swift
//

import Foundation

// Q. better to implement this as pack/unpack protocol, leaving clients to implement their own structs/classes (if so, we need more capable conversion funcs, including ability to specify optionals, enums, etc)

// TO DO: define separate descriptor structs for constructing specifiers? or define as methods on RecordDescriptor which pack/unpack Data directly

// TO DO: what about AERecords with arbitrary type, e.g. `{class:document,name:…}`? one option is to make internal init public and trust clients to implement correctly; another is to implement 'RecordBuilder' struct that implements `public mutating func set(key:value:using:) throws`, or `public mutating func set(key:OSType,value:Descriptor)[throws?]` which is called repeatedly to pack each attribute (this func can be used to pack dynamic dictionaries as well as static structs); a third is to make RecordDescriptor mutable, appending directly to its data and updating existing keys, count, and bytes remaining each time (might be best to have `static func with{…}` style method which passes in a RecordBuilder and initializes the RecordDescriptor on return); or we can iterate an [(OSType,Descriptor)] sequence (although we're trying to avoid unnecessary looping)



/*
 wrapped typeAERecord (wrapped typeAEList has the same layout):
 
     1684825394      'dle2'             # format
     0               '\x00\x00\x00\x00' # align
     1919247215      'reco'             # type
     64              '\x00\x00\x00@'    # bytes remaining
 
     0               '\x00\x00\x00\x00' # ? (these 16 bytes only appear when type is list/reco)
     0               '\x00\x00\x00\x00' # ?
     24              '\x00\x00\x00\x18' # ?
     1919247215      'reco'             # ? type
 
     3               '\x00\x00\x00\x03' # count
     0               '\x00\x00\x00\x00' # align
     …
 
 wrapped records with any other type omit the middle block (i.e. same layout as wrapped scalar descriptor):
 
     1684825394      'dle2'             # format
     0               '\x00\x00\x00\x00' # align
     1685021557      'docu'             # type
     32              '\x00\x00\x00 '    # bytes remaining
 
     2               '\x00\x00\x00\x02' # count
     0               '\x00\x00\x00\x00' # align
     …
 
 nested lists/records always use short form:
 
     1919247215      'reco'             # type
     24              '\x00\x00\x00\x18' # remaining bytes (TBC)
     1               '\x00\x00\x00\x01' # count
     0               '\x00\x00\x00\x00' # align
 */

/*
 Each property in record consists of a key (OSType) and associated value (flattened AEDesc), e.g:
 
 1886282093      'pnam'             # key
 1954115685      'type'             # value (type)
 4               '\x00\x00\x00\x04' # value (bytes remaining)
 1685021557      'docu'             # value (data)
 */



public struct RecordDescriptor: IterableDescriptor {
    
    public var debugDescription: String {
        return "<\(Swift.type(of: self)) [\(self.map{ "\(literalFourCharCode($0)):\($1.debugDescription)" }.joined(separator: ", "))]>"
    }
        
    public typealias Element = (key: AEKeyword, value: Descriptor)
    public typealias Iterator = DescriptorIterator<RecordDescriptor>
    
    public let type: DescType
    public let count: UInt32
    public let data: Data // caution: whereas AEGetDescData() returns complete flattened list/record (dle2), this contains list items only; use flatten()/appendTo() to get complete list data // note: client code may wish to define its own list unpacking routines, e.g. Point/Rectangle may be quicker parsing list themselves rather than unpacking as [Int] and converting from that, particularly when supporting legacy QD struct representations as well)
    
    public init(type: DescType, count: UInt32, data: Data) { // also called by unflattenFirstDescriptor
        self.type = type
        self.count = count
        self.data = data // key-value pairs, where key is DescType and value is added via appendTo()
    }
    
    // iteration
    
    public __consuming func makeIterator() -> Iterator {
        return Iterator(self)
    }
    
    public func element(at offset: Int) -> (item: Element, endOffset: Int) {
        let key = self.data.readUInt32(at: offset)
        let (value, endOffset) = unflattenFirstDescriptor(in: self.data, startingAt: offset + 4)
        return ((key, value) as Element, endOffset)
    }
    
    // TO DO: what about `descriptor(for key:)->Descriptor`? or do we require client code to unpack via iterator? could provide RecordReader as complement to RecordBuilder (records tend to be short, so just loop over keys and remaining bytes to build a map of keys to value offsets up front); that would allow non-sequential access by key while ignoring unknown fields or throwing on missing fields (unpackfuncs can use same technique as sylvia lang to intercept key-not-found errors and return default values for fields that can have them), and both can be driven from a single IDL definition
    
    // serialization
    
    public func flatten() -> Data {
        var result = Data([0x64, 0x6c, 0x65, 0x32,    // 'dle2' format marker
                           0, 0, 0, 0])               // align
        result += encodeUInt32(self.type)             // type
        result += Data([0, 0, 0, 0])                  // remaining bytes (TBC)
        if self.type == typeAERecord {                // reserved block ('dle2'-wrapped 'reco' only)
            result += Data([0, 0, 0, 0,
                            0, 0, 0, 0,
                            0, 0, 0, 0x18])
            result += encodeUInt32(self.type)         // type (again)
        }
        result += encodeUInt32(UInt32(self.count))    // number of items
        result += Data([0, 0, 0, 0])                  // align
        result += self.data                           // zero or more key-value pairs
        result[(result.startIndex + 12)..<(result.startIndex + 16)] = encodeUInt32(UInt32(result.count - 16)) // calculate and set remaining bytes
        return result
    }
    
    public func appendTo(containerData result: inout Data) {
        // appends this record to a list (item), record (property value), or event (attribute/parameter value)
        result += encodeUInt32(self.type)                     // type
        result += encodeUInt32(UInt32(self.data.count + 8))   // remaining bytes (= count + align + self.data)
        result += encodeUInt32(self.count)                    // number of items
        result += Data([0, 0, 0, 0])                          // align
        result += self.data                                   // zero or more key-value pairs
    }
}




public extension RecordDescriptor {
    
    // note: when packing/unpacking as dictionaries, T is normally `Any` as typical record properties are mixed type
    
    // TO DO: how best to handle non-reco descriptor types? (for now we attempt to store record type as 'class' property, c.f. AppleScript records, with the caveat that this information is silently discarded if DescType cannot be cast to/from T)
    
    // TO DO: optional keyFunc for mapping dictionary keys to/from AEKeyword (this'll also allow for better error messages, using dictionary keys instead of four-char codes when possible)
    
    func dictionary<T>(using unpackFunc: (Descriptor) throws -> T) rethrows -> [AEKeyword: T] { // TO DO: should unpack func take (AEKeyword,Descriptor) and return (K,V)?
        var result = [AEKeyword: T]()
        if self.type != typeAERecord, let cls = self.type as? T {
            result[pClass] = cls
        }
        for (key, descriptor) in self {
            do {
                result[key] = try unpackFunc(descriptor)
            } catch {
                throw AppleEventError(message: "Can't unpack item \(literalFourCharCode(key)) of record.", cause: error)
            }
        }
        return result
    }
}



