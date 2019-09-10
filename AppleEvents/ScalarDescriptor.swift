//
//  AppleEventDescriptor.swift
//
//  Carbon AEDesc reimplemented in Swift



// type128BitFloatingPoint, typeDecimalStruct?


import Foundation


// caution: when appending scalar descriptors containing arbitrary-length data (e.g. typeBoolean, typeUTF8Text) to AEList/AERecord/AppleEvent, the appended data must end on even-numbered byte

func align(data: inout Data) {
    if data.count % 2 != 0 { data += Data([0]) }
}


public struct ScalarDescriptor: Descriptor, Scalar {
    
    public var debugDescription: String {
        var value = try? unpackAsAny(self)
        if let string = value as? String {
            value = string.debugDescription
        } else if value is Descriptor {
            if let code = try? unpackAsFourCharCode(self) {
                value = literalFourCharCode(code)
            } else {
                value = nil
            }
        }
        return "<\(Swift.type(of: self)) \(literalFourCharCode(self.type)) \(value ?? "...")>"
    }

    public let type: DescType
    public let data: Data
    
    public init(type: DescType, data: Data) {
        self.type = type
        self.data = data
    }
}


public protocol Scalar: Descriptor {}

public extension Scalar {

    func flatten() -> Data {
        var result = Data([0x64, 0x6c, 0x65, 0x32,    // format 'dle2'
                           0, 0, 0, 0])               // align
        self.appendTo(containerData: &result)
        return result
    }
    
    func appendTo(containerData result: inout Data) {
        let data = self.data
        result += encodeUInt32(self.type)          // descriptor type
        result += encodeUInt32(UInt32(data.count)) // remaining bytes
        result += data                           // descriptor data
        align(data: &result)                                 // even-byte align (e.g. Booleans, UTF8 strings)
    }
}


internal let nullData = Data(capacity: 0)

public let nullDescriptor = ScalarDescriptor(type: typeNull, data: nullData)
let trueDescriptor = ScalarDescriptor(type: typeTrue, data: nullData)
let falseDescriptor = ScalarDescriptor(type: typeFalse, data: nullData)

// TO DO: bridge Swift nil/cMissingValue? (cMissingValue is another AS/AE wart: it'd be much simpler and saner had original designers used typeNull as their "no-value" value, but backwards-compatibility with existing AS/AE/App ecosystem requires using `missing value`; SwiftAutomation seems to have found a reasonable compromise)
public let missingValueDescriptor = ScalarDescriptor(type: typeType, data: Data([0x6D, 0x73, 0x6E, 0x67])) // cMissingValue


