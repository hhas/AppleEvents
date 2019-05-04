//
//  AppleEventDescriptor.swift
//
//  Carbon AEDesc reimplemented in Swift

// TO DO: standard coercions are built in; what about client-defined coercions? (presumably use global handler table, and have `default` clause in switches call `customCoerceTo`; note: table presumably needs to include standard coercions as well, for use in situations where client code wants to coerce from one desc to another; simplest way to implement these handlers is as `packTYPE(unpackTYPE(desc))`, which may be a bit wasteful, but should be safest and simplest)

// note: type-driven `unpack(Descriptor)->T` is problematic for URL and OSType, an argument in favor of named funcs, e.g. unpackFileURL, unpackInt; ditto for packing

// important: integers must be serialized as big-endian (in AEM, endian normalization done when packing integer descriptors into lists/records; e.g. a typeSInt32 descriptor is built as native-endian, but when added to a list AEM converts it to big-endian; we can simplify this by requiring big-endian conversion is done immediately upon packing/unpacking integers)

// type128BitFloatingPoint, typeDecimalStruct?


import Foundation



public struct ScalarDescriptor: Descriptor, Scalar {
    
    public let type: DescType
    public let data: Data
}


protocol Scalar: Descriptor {}

extension Scalar {

    public func flatten() -> Data {
        var result = Data([0x64, 0x6c, 0x65, 0x32,    // format 'dle2'
                           0, 0, 0, 0])               // align
        result += packUInt32(self.type)               // descriptor type
        result += packUInt32(UInt32(self.data.count)) // remaining bytes
        result += self.data                           // descriptor data
        return result
    }
    
    public func appendTo(containerData result: inout Data) {
        result += packUInt32(self.type)               // descriptor type
        result += packUInt32(UInt32(self.data.count)) // remaining bytes
        result += self.data                           // descriptor data
    }
}


internal let nullData = Data(capacity: 0)

let nullDescriptor = ScalarDescriptor(type: typeNull, data: nullData)
let trueDescriptor = ScalarDescriptor(type: typeTrue, data: nullData)
let falseDescriptor = ScalarDescriptor(type: typeFalse, data: nullData)







/*
extension AppleEventDescriptor: SelfPacking, SelfUnpacking {
    public func SwiftAutomation_packSelf(_ appData: AppData) throws -> AppleEventDescriptor { // TO DO: ownership? (problem is that Specifier, Symbol, AppleEventDescriptor are returning existing cached AEDesc whereas Array, Dictionary, Set return newly created AEDesc); for now, safest to copy cached descs before returning
        return self
    }
    static public func SwiftAutomation_unpackSelf(_ desc: AppleEventDescriptor, appData: AppData) throws -> Self {
        return self.init(desc: desc)
    }
    
    static public func SwiftAutomation_noValue() throws -> Self {
        return self.init(desc: nullDescriptor)
    }
}
*/
