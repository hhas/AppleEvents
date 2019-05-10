//
//  AppleEventDescriptor.swift
//
//  Carbon AEDesc reimplemented in Swift



// type128BitFloatingPoint, typeDecimalStruct?


import Foundation



public struct ScalarDescriptor: Descriptor, Scalar {
    
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
    }
}


internal let nullData = Data(capacity: 0)

public let nullDescriptor = ScalarDescriptor(type: typeNull, data: nullData)
let trueDescriptor = ScalarDescriptor(type: typeTrue, data: nullData)
let falseDescriptor = ScalarDescriptor(type: typeFalse, data: nullData)

// TO DO: bridge Swift nil/cMissingValue? (cMissingValue is another AS/AE wart: it'd be much simpler and saner had original designers used typeNull as their "no-value" value, but backwards-compatibility with existing AS/AE/App ecosystem requires using `missing value`; SwiftAutomation seems to have found a reasonable compromise)
public let missingValueDescriptor = ScalarDescriptor(type: typeType, data: Data([0x6D, 0x73, 0x6E, 0x67])) // cMissingValue




