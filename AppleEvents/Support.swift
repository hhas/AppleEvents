//
//  Support.swift
//

// TO DO: which utility funcs should be public?

import Foundation


//#if !canImport(Carbon)

public typealias OSType = UInt32
public typealias DescType = OSType
public typealias AEKeyword = OSType

//#endif


public typealias EventIdentifier = UInt64 // combined eventClass and eventID


public let noOSType: OSType = 0

internal let epochDelta: TimeInterval = 35430.0 * 24 * 3600; // offset from 1904-01-01 to 2001-01-01

internal var isLittleEndianHost: Bool { let n: UInt16 = 1; return n.littleEndian == n }



extension Data {
    func readUInt32(at offset: Int) -> UInt32 { // read desc type, bytes remaining, count, etc; caution: this does not perform bounds checks // important: Data slices may not start at 0; use `data.readUInt32(at:data.startIndex+offset)`
        return try! decodeUInt32(self[offset..<(offset + 4)])
    }
}



// used by encodeTYPE/decodeTYPE funcs; caution: do not use directly for integer conversions as they are not endian-safe

internal func encodeFixedWidthValue<T>(_ value: T) -> Data {
    return Swift.withUnsafeBytes(of: value){ Data($0) }
}

internal func decodeFixedWidthValue<T>(_ data: Data) throws -> T {
    if data.count != MemoryLayout<T>.size { throw AppleEventError.corruptData }
    return data.withUnsafeBytes{ $0.baseAddress!.assumingMemoryBound(to: T.self).pointee } // TO DO: use bindMemory(to:capacity:)?
}


// endian-safe integer pack/unpack (caution: these store numeric values as big-endian so are not binary-compatible with Carbon AEDescs' storage (numeric AEDescs use native-endian storage and only convert to big-endian when packed into a complex [list/record/event] descriptor) // also used in SwiftAutomation.AETEParser

public func encodeFixedWidthInteger<T: FixedWidthInteger>(_ value: T) -> Data {
    return encodeFixedWidthValue(T(bigEndian: value))
}
public func decodeFixedWidthInteger<T: FixedWidthInteger>(_ data: Data) throws -> T {
    return T(bigEndian: try decodeFixedWidthValue(data))
}

// convenience wrappers around the above // TO DO: internal?

public func encodeInt64(_ value: Int64) -> Data {
    return encodeFixedWidthInteger(value)
}
public func encodeInt32(_ value: Int32) -> Data { // e.g. pid_t
    return encodeFixedWidthInteger(value)
}
public func encodeInt16(_ value: Int16) -> Data { // e.g. AEReturnID
    return encodeFixedWidthInteger(value)
}
public func encodeInt8(_ value: Int8) -> Data {
    return encodeFixedWidthInteger(value)
}

public func encodeUInt64(_ value: UInt64) -> Data { // e.g. EventIdentifier
    return encodeFixedWidthInteger(value)
}
public func encodeUInt32(_ value: UInt32) -> Data { // e.g. OSType
    return encodeFixedWidthInteger(value)
}
public func encodeUInt16(_ value: UInt16) -> Data {
    return encodeFixedWidthInteger(value)
}
public func encodeUInt8(_ value: UInt8) -> Data {
    return encodeFixedWidthInteger(value)
}



public func decodeInt64(_ data: Data) throws -> Int64 {
    return try decodeFixedWidthInteger(data)
}
public func decodeInt32(_ data: Data) throws -> Int32 {
    return try decodeFixedWidthInteger(data)
}
public func decodeInt16(_ data: Data) throws -> Int16 {
    return try decodeFixedWidthInteger(data)
}
public func decodeInt8(_ data: Data) throws -> Int8 {
    return try decodeFixedWidthInteger(data)
}

public func decodeUInt64(_ data: Data) throws -> UInt64 {
    return try decodeFixedWidthInteger(data)
}
public func decodeUInt32(_ data: Data) throws -> UInt32 {
    return try decodeFixedWidthInteger(data)
}
public func decodeUInt16(_ data: Data) throws -> UInt16 {
    return try decodeFixedWidthInteger(data)
}
public func decodeUInt8(_ data: Data) throws -> UInt8 {
    return try decodeFixedWidthInteger(data)
}

// pack/unpack UTF8-encoded data used in various descriptors (e.g. typeUTF8Text, typeFileURL, typeApplicationBundleID)

internal func encodeUTF8String(_ value: String) -> Data { // confirm fileURL, bundleID is always UTF8-encoded
    return Data(value.utf8)
}

internal func decodeUTF8String(_ data: Data) -> String? {
    return String(data: data, encoding: .utf8)
}

// ditto for ISO8601 date strings (although AE dates are traditionally Int64)

func encodeISO8601Date(_ value: Date) throws -> Data {
    return encodeUTF8String(ISO8601DateFormatter().string(from: value))
}

func decodeISO8601Date(_ data: Data) throws -> Date? {
    if let string = decodeUTF8String(data) { return ISO8601DateFormatter().date(from: string) }
    return nil
}


// utility functions for creating and splitting eight-char codes

public func eventIdentifier(_ eventClass: AEEventClass, _ eventID: AEEventID) -> EventIdentifier {
    return (UInt64(eventClass) << 32) | UInt64(eventID)
}

public func eventIdentifier(_ eventIdentifier: EventIdentifier) -> (AEEventClass, AEEventID) {
    return (UInt32(eventIdentifier >> 32), UInt32(eventIdentifier % (1 << 32)))
}


// convert an OSType to String literal representation, e.g. 'docu' -> "\"docu\"", or hexadecimal integer if it contains problem characters

public func literalFourCharCode(_ code: OSType) -> String {
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

public func literalEightCharCode(_ code: EventIdentifier) -> String {
    var bigCode = UInt64(bigEndian: code)
    var result = ""
    for _ in 0..<MemoryLayout.size(ofValue: code) {
        let c = bigCode % 256
        if c < 0x20 || c == 0x27 || c == 0x5C || c > 0x7E { // found a non-printing, backslash, single quote, or non-ASCII character
            return String(format: "0x%08x_%08x", UInt32(code >> 32), UInt32(code % (1 << 32)))
        }
        result += String(format: "%c", c)
        bigCode >>= 8
    }
    return "\"\(result)\""
}


// TO DO: functions for converting to/from four-char MacRoman strings


// development

public func dumpFourCharData(_ data: Data) {
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
