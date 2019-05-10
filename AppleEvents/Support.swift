//
//  Support.swift
//

//import Foundation
import Foundation

public typealias OSType = UInt32
public typealias DescType = OSType
public typealias AEKeyword = OSType

let noOSType: OSType = 0

internal let epochDelta: TimeInterval = 35430.0 * 24 * 3600; // offset from 1904-01-01 to 2001-01-01

internal var isLittleEndianHost: Bool { let n: UInt16 = 1; return n.littleEndian == n }



extension Data {
    func readUInt32(at offset: Int) -> UInt32 { // read desc type, bytes remaining, count, etc; caution: this does not perform bounds checks // important: Data slices may not start at 0; use `data.readUInt32(at:data.startIndex+offset)`
        return try! unpackUInt32(self[offset..<(offset + 4)])
    }
}


// convert an OSType to String literal representation, e.g. 'docu' -> "\"docu\"", or hexadecimal integer if it contains problem characters
func literalFourCharCode(_ code: OSType) -> String {
    var bigCode = UInt32(bigEndian: code)
    var result = ""
    for _ in 0..<MemoryLayout.size(ofValue: code) {
        let c = bigCode % 256
        if c < 0x20 || c == 0x27 || c == 0x5C || c > 0x7E { // found a non-printing, backslash, single quote, or non-ASCII character
            return String(format: "0x%08x", code)
        }
        result += String(format: "%c", c)
        bigCode >>= 8
    }
    return "\"\(result)\""
}

func literalEightCharCode(_ code: UInt64) -> String {
    var bigCode = UInt64(bigEndian: code)
    var result = ""
    for _ in 0..<MemoryLayout.size(ofValue: code) {
        let c = bigCode % 256
        if c < 0x20 || c == 0x27 || c == 0x5C || c > 0x7E { // found a non-printing, backslash, single quote, or non-ASCII character
            return String(format: "0x%08x", code)
        }
        result += String(format: "%c", c)
        bigCode >>= 8
    }
    return "\"\(result)\""
}

// TO DO: rename the following flattenTYPE/unflattenTYPE; use pack/unpack for Descriptor only

// packing/unpacking primitives; these are used by pack/unpack funcs and flatten/unflatten methods
// caution: these methods are NOT endian-safe; do not call directly to pack/unpack integers

internal func packFixedSize<T>(_ value: T) -> Data {
    return Swift.withUnsafeBytes(of: value) { Data($0) }
}

internal func unpackFixedSize<T>(_ data: Data) throws -> T {
    if data.count != MemoryLayout<T>.size { throw AppleEventError.corruptData }
    return data.withUnsafeBytes{ $0.baseAddress!.assumingMemoryBound(to: T.self).pointee } // TO DO: use bindMemory(to:capacity:)?
}

// endian-safe integer pack/unpack (caution: these store numeric values as big-endian so are not binary-compatible with Carbon AEDescs' storage (numeric AEDescs use native-endian storage and only convert to big-endian when packed into a complex [list/record/event] descriptor)

internal func packInteger<T: FixedWidthInteger>(_ value: T) -> Data {
    return packFixedSize(T(bigEndian: value))
}
public func packUInt32(_ value: UInt32) -> Data { // e.g. OSType
    return packFixedSize(UInt32(bigEndian: value))
}
internal func packInt32(_ value: Int32) -> Data {
    return packFixedSize(Int32(bigEndian: value))
}
internal func packInt16(_ value: Int16) -> Data {
    return packFixedSize(Int16(bigEndian: value))
}

public func unpackUInt32(_ data: Data) throws -> UInt32 { // e.g. OSType
    return UInt32(bigEndian: try unpackFixedSize(data))
}
internal func unpackInt32(_ data: Data) throws -> Int32 { // e.g. pid_t
    return Int32(bigEndian: try unpackFixedSize(data))
}
internal func unpackInt16(_ data: Data) throws -> Int16 { // e.g. AEReturnID
    return Int16(bigEndian: try unpackFixedSize(data))
}

// pack/unpack UTF8-encoded data used in various descriptors (e.g. typeUTF8Text, typeFileURL, typeApplicationBundleID)

internal func packUTF8String(_ value: String) -> Data { // confirm fileURL, bundleID is always UTF8-encoded
    return Data(value.utf8)
}

internal func unpackUTF8String(_ data: Data) throws -> String {
    guard let result = String(data: data, encoding: .utf8) else { throw AppleEventError.corruptData }
    return result
}


// utility functions for creating and splitting eight-char codes

public func eventIdentifier(_ eventClass: AEEventClass, _ eventID: AEEventID) -> EventIdentifier {
    return (UInt64(eventClass) << 32) | UInt64(eventID)
}

public func eventIdentifier(_ eventIdentifier: EventIdentifier) -> (AEEventClass, AEEventID) {
    return (UInt32(eventIdentifier >> 32), UInt32(eventIdentifier % (1 << 32)))
}


//

public func dumpFourCharData(_ data: Data) { // DEBUG
    let data = Data(data)
    print("/*")
    for i in 0..<(data.count / 4) {
        print(" * ", literalFourCharCode(data.readUInt32(at: i * 4)))
    }
    let rem = data.count % 4
    if rem != 0 {
        var n = "0x"; var s: String! = ""
        for c in data[(data.count - rem)..<(data.count)] {
            if c < 0x20 || c == 0x27 || c == 0x5C || c > 0x7E { s = nil }
            n += String(format: "%02x", c)
            if s != nil { s += String(format: "%c", c) }
        }
        print(" * ", s != nil ? "\"\(s!)\"" : n)
    }
    print(" */")
}
