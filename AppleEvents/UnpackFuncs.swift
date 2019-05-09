//
//  Unpack.swift
//
// standard unpack functions for converting AE descriptors to specified Swift types, coercing as needed (or throwing if the given descriptor can't be coerced to the required type)
//

// TO DO: what about packAsDescriptor/unpackAsDescriptor? (for use in packAsArray/unpackAsArray/packAsDictionary/etc for shallow packing/unpacking); also need to decide on packAsAny/unpackAsAny, and packAs<T>/unpackAs<T> (currently SwiftAutomation implements these, with support for App-specific Symbols and Specifiers)


import Foundation


public func unpackAsBool(_ descriptor: Descriptor) throws -> Bool {
    switch descriptor.type {
    case typeTrue:
        return true
    case typeFalse:
        return false
    case typeBoolean:
        return try unpackFixedSize(descriptor.data)
    case typeSInt64, typeSInt32, typeSInt16:
        switch try unpackAsInteger(descriptor) as Int {
        case 1: return true
        case 0: return false
        default: throw AppleEventError.unsupportedCoercion
        }
    case typeUInt64, typeUInt32, typeUInt16:
        switch try unpackAsInteger(descriptor) as UInt {
        case 1: return true
        case 0: return false
        default: throw AppleEventError.unsupportedCoercion
        }
    case typeUTF8Text, typeUTF16ExternalRepresentation, typeUnicodeText:
        switch try unpackAsString(descriptor).lowercased() {
        case "true", "yes": return true
        case "false", "no": return false
        default: throw AppleEventError.unsupportedCoercion
        }
    default:
        throw AppleEventError.unsupportedCoercion
    }
}


private func unpackAsInteger<T: FixedWidthInteger>(_ descriptor: Descriptor) throws -> T {
    // caution: AEs are big-endian; unlike AEM's integer descriptors, which for historical reasons hold native-endian data and convert to big-endian later on, we immediately convert to/from big-endian
    var result: T? = nil
    switch descriptor.type {
    case typeSInt64:
        result = T(exactly: Int64(bigEndian: try unpackFixedSize(descriptor.data)))
    case typeSInt32:
        result = T(exactly: Int32(bigEndian: try unpackFixedSize(descriptor.data)))
    case typeSInt16:
        result = T(exactly: Int16(bigEndian: try unpackFixedSize(descriptor.data)))
    case typeUInt64:
        result = T(exactly: UInt64(bigEndian: try unpackFixedSize(descriptor.data)))
    case typeUInt32:
        result = T(exactly: UInt32(bigEndian: try unpackFixedSize(descriptor.data)))
    case typeUInt16:
        result = T(exactly: UInt16(bigEndian: try unpackFixedSize(descriptor.data)))
    // coercions
    case typeTrue, typeFalse, typeBoolean:
        result = try unpackAsBool(descriptor) ? 1 : 0
    case typeIEEE32BitFloatingPoint:
        result = T(exactly: try unpackFixedSize(descriptor.data) as Float)
    case typeIEEE64BitFloatingPoint: // Q. what about typeIEEE128BitFloatingPoint?
        result = T(exactly: try unpackFixedSize(descriptor.data) as Double)
    case typeUTF8Text, typeUTF16ExternalRepresentation, typeUnicodeText: // TO DO: do we care about non-Unicode strings (typeText? typeStyledText? etc) or are they sufficiently long-deprecated to ignore now (i.e. what, if any, macOS apps still use them?)
        result = T(try unpackAsString(descriptor)) // result is nil if non-numeric string // TO DO: any difference in how AEM converts string to integer?
    default:
        throw AppleEventError.unsupportedCoercion
    }
    guard let n = result else { throw AppleEventError.unsupportedCoercion }
    return n
}


public func unpackAsInt(_ descriptor: Descriptor) throws -> Int {
    return try unpackAsInteger(descriptor)
}
public func unpackAsUInt(_ descriptor: Descriptor) throws -> UInt {
    return try unpackAsInteger(descriptor)
}
public func unpackAsInt16(_ descriptor: Descriptor) throws -> Int16 {
    return try unpackAsInteger(descriptor)
}
public func unpackAsUInt16(_ descriptor: Descriptor) throws -> UInt16 {
    return try unpackAsInteger(descriptor)
}
public func unpackAsInt32(_ descriptor: Descriptor) throws -> Int32 {
    return try unpackAsInteger(descriptor)
}
public func unpackAsUInt32(_ descriptor: Descriptor) throws -> UInt32 {
    return try unpackAsInteger(descriptor)
}
public func unpackAsInt64(_ descriptor: Descriptor) throws -> Int64 {
    return try unpackAsInteger(descriptor)
}
public func unpackAsUInt64(_ descriptor: Descriptor) throws -> UInt64 {
    return try unpackAsInteger(descriptor)
}


public func unpackAsDouble(_ descriptor: Descriptor) throws -> Double { // coerces as needed
    switch descriptor.type {
    case typeIEEE64BitFloatingPoint:
        return try unpackFixedSize(descriptor.data)
    case typeIEEE32BitFloatingPoint:
        return Double(try unpackFixedSize(descriptor.data) as Float)
    case typeSInt64, typeSInt32, typeSInt16:
        return Double(try unpackAsInteger(descriptor) as Int)
    case typeUInt64, typeUInt32, typeUInt16:
        return Double(try unpackAsInteger(descriptor) as UInt)
    case typeUTF8Text, typeUTF16ExternalRepresentation, typeUnicodeText:
        guard let result = Double(try unpackAsString(descriptor)) else {
            throw AppleEventError.unsupportedCoercion
        }
        return result
    default:
        throw AppleEventError.unsupportedCoercion
    }
}


public func unpackAsString(_ descriptor: Descriptor) throws -> String { // coerces as needed
    switch descriptor.type {
        // typeUnicodeText: native endian UTF16 with optional BOM (deprecated, but still in common use)
        // typeUTF16ExternalRepresentation: big-endian 16 bit unicode with optional byte-order-mark,
    //                                  or little-endian 16 bit unicode with required byte-order-mark
    case typeUTF8Text:
        return try unpackUTF8String(descriptor.data)
    case typeUTF16ExternalRepresentation, typeUnicodeText: // UTF-16 BE/LE
        if descriptor.data.count < 2 {
            if descriptor.data.count > 0 { throw AppleEventError.corruptData }
            return ""
        }
        var bom: UInt16 = 0 // check for BOM before decoding
        let _ = Swift.withUnsafeMutableBytes(of: &bom, { descriptor.data.copyBytes(to: $0)} )
        let encoding: String.Encoding
        switch bom {
        case 0xFEFF:
            encoding = .utf16BigEndian
        case 0xFFFE:
            encoding = .utf16LittleEndian
        default: // no BOM; if typeUnicodeText use platform endianness, else it's big-endian typeUTF16ExternalRepresentation
            encoding = (descriptor.type == typeUnicodeText && isLittleEndianHost) ? .utf16LittleEndian : .utf16BigEndian
        }
        // TO DO: FIX; endianness bug when decoding typeUnicodeText
        //print("ENCODING:", encoding)
        //print(descriptor.data[0..<4])
        /*
         
         public var typeStyledUnicodeText: DescType { get } /* Not implemented */
         public var typeEncodedString: DescType { get } /* Not implemented */
         public var typeUnicodeText: DescType { get } /* native byte ordering, optional BOM */
         public var typeCString: DescType { get } /* MacRoman characters followed by a NULL byte */
         public var typePString: DescType { get } /* Unsigned length byte followed by MacRoman characters */
         
         /*
         * The preferred unicode text types.  In both cases, there is no explicit null termination or length byte.
         */
         
         public var typeUTF16ExternalRepresentation: DescType { get } /* big-endian 16 bit unicode with optional byte-order-mark, or little-endian 16 bit unicode with required byte-order-mark. */
         public var typeUTF8Text: DescType { get } /* 8 bit unicode */

         */
        guard let result = String(data: descriptor.data, encoding: encoding) else { throw AppleEventError.corruptData }
       // print("STRING:", result)
        return result
    // TO DO: boolean, number
    case typeSInt64, typeSInt32, typeSInt16:
        return String(try unpackAsInteger(descriptor) as Int64)
    case typeUInt64, typeUInt32, typeUInt16:
        return String(try unpackAsInteger(descriptor) as UInt64)
    // TO DO: what about typeFileURL? AEM has unpleasant habit of coercing that to typeUnicodeText as HFS(!) path, which we don't want to do (AEM also fails to coerce it to typeUTF8Text)
    // TO DO: typeVersion?
    // TO DO: throw on legacy types? (typeChar, typeIntlText, typeStyledText)
    default:
        throw AppleEventError.unsupportedCoercion
    }
}


public func unpackAsDate(_ descriptor: Descriptor) throws -> Date {
    let delta: TimeInterval
    switch descriptor.type {
    case typeLongDateTime: // assumes data handle is valid for descriptor type
        delta = TimeInterval(try unpackAsInteger(descriptor) as Int64)
    default:
        throw AppleEventError.unsupportedCoercion
    }
    return Date(timeIntervalSinceReferenceDate: delta + epochDelta)
}


public func unpackAsFileURL(_ descriptor: Descriptor) throws -> URL {
    switch descriptor.type {
    case typeFileURL:
        guard let result = URL(dataRepresentation: descriptor.data, relativeTo: nil, isAbsolute: true), result.isFileURL else {
            throw AppleEventError.corruptData
        }
        return result
        // TO DO: what about bookmarks?
        /*
         case typeBookmarkData:
         do {
         var bookmarkDataIsStale = false
         return try URL(resolvingBookmarkData: descriptor.data, bookmarkDataIsStale: &bookmarkDataIsStale)
         } catch {
         throw AppleEventError(code: -1702, cause: error)
         }
         */
    case typeUTF8Text, typeUTF16ExternalRepresentation, typeUnicodeText:
        // TO DO: relative paths?
        guard let path = try? unpackAsString(descriptor), path.hasPrefix("/") else {
            throw AppleEventError.unsupportedCoercion
        }
        return URL(fileURLWithPath: path)
    // TO DO: what other cases? typeAlias, typeFSRef are deprecated (typeAlias is still commonly used by AS, but would require use of deprecated APIs to coerce/unpack)
    default:
        throw AppleEventError.unsupportedCoercion
    }
}


public func unpackAsType(_ descriptor: Descriptor) throws -> OSType {
    // TO DO: how should cMissingValue be handled? (there is an argument for special-casing it, throwing a coercion error which `unpackAsOptional(_:using:)`) can intercept to return nil instead
    switch descriptor.type {
    case typeType, typeProperty, typeKeyword:
        return try unpackUInt32(descriptor.data)
    default:
        throw AppleEventError.unsupportedCoercion
    }
}


public func unpackAsEnum(_ descriptor: Descriptor) throws -> OSType {
    switch descriptor.type {
    case typeEnumerated, typeAbsoluteOrdinal:
        return try unpackUInt32(descriptor.data)
    default:
        throw AppleEventError.unsupportedCoercion
    }
}

public func unpackAsFourCharCode(_ descriptor: Descriptor) throws -> OSType {
    switch descriptor.type {
    case typeEnumerated, typeAbsoluteOrdinal, typeType, typeProperty, typeKeyword:
        return try unpackUInt32(descriptor.data)
    default:
        throw AppleEventError.unsupportedCoercion
    }
}

public func unpackAsDescriptor(_ descriptor: Descriptor) -> Descriptor {
    return descriptor
}

// TO DO: what about unpackAsSequence?

public func newUnpackArrayFunc<T>(using unpackFunc: @escaping (Descriptor) throws -> T) -> (Descriptor) throws -> [T] {
    return { try unpackAsArray($0, using: unpackFunc) }
}

public func unpackAsArray<T>(_ descriptor: Descriptor, using unpackFunc: (Descriptor) throws -> T) rethrows -> [T] {
    if let listDescriptor = descriptor as? ListDescriptor { // any non-list value is coerced to single-item list
        return try listDescriptor.array(using: unpackFunc)
    } else {
        // TO DO: typeQDPoint, typeQDRectangle, typeRGBColor (legacy support as various Carbon-based apps still use these types)
        return [try unpackFunc(descriptor)]
    }
}


// TO DO: how to unpack AERecords as structs?

public func unpackAsDictionary<T>(_ descriptor: Descriptor, using unpackFunc: (Descriptor) throws -> T) throws -> [AEKeyword: T] {
    // TO DO: this is problematic as it requires unflattenDescriptor() to recognize AERecords with non-reco type and return them as RecordDescriptor, not ScalarDescriptor; e.g. an AERecord of type cDocument has the same layout as non-collection AEDescs of typeInteger/typeUTF8Text/etc, so how does AEIsRecord() tell the difference?
    guard let recordDescriptor = descriptor as? RecordDescriptor else { throw AppleEventError.unsupportedCoercion }
    return try recordDescriptor.dictionary(using: unpackFunc)
}


// Q. how to represent 'missing value' when unpacking as Any?

public func unpackAsAny(_ descriptor: Descriptor) throws -> Any {
    let result: Any
    switch descriptor.type {
    case typeTrue:
        result = true
    case typeFalse:
        result = false
    case typeBoolean:
        result = descriptor.data != Data([0])
    case typeSInt64:
        let n = Int64(bigEndian: try unpackFixedSize(descriptor.data))
        result = Int(exactly: n) ?? n // on 32-bit machines, return Int64 if out-of-range for 32-bit Int
    case typeSInt32:
        result = Int(Int32(bigEndian: try unpackFixedSize(descriptor.data)))
    case typeSInt16:
        result = Int(Int16(bigEndian: try unpackFixedSize(descriptor.data)))
    case typeUInt64:
        let n = UInt64(bigEndian: try unpackFixedSize(descriptor.data))
        result = UInt(exactly: n) ?? n // ditto
    case typeUInt32:
        result = UInt(UInt32(bigEndian: try unpackFixedSize(descriptor.data)))
    case typeUInt16:
        result = UInt(UInt16(bigEndian: try unpackFixedSize(descriptor.data)))
    case typeIEEE32BitFloatingPoint:
        result = try unpackAsDouble(descriptor)
    case typeIEEE64BitFloatingPoint: // Q. what about typeIEEE128BitFloatingPoint?
        result = try unpackFixedSize(descriptor.data) as Double
    case typeUTF8Text:
        result = try unpackUTF8String(descriptor.data)
    case typeUTF16ExternalRepresentation, typeUnicodeText: // TO DO: do we care about non-Unicode strings (typeText? typeStyledText? etc) or are they sufficiently long-deprecated to ignore now (i.e. what, if any, macOS apps still use them?)
        result = try unpackAsString(descriptor) // result is nil if non-numeric string // TO DO: any difference in how AEM converts string to integer?
    case typeLongDateTime:
        result = try unpackAsDate(descriptor)
    case typeFileURL:
        result = try unpackAsFileURL(descriptor)
    case typeAEList:
        result = try unpackAsArray(descriptor, using: unpackAsAny)
    case typeAERecord:
        result = try unpackAsDictionary(descriptor, using: unpackAsAny)
    case typeQDPoint, typeQDRectangle, typeRGBColor:
        return try unpackAsArray(descriptor, using: unpackAsInt)
    default:
        result = descriptor
    }
    return result
}

