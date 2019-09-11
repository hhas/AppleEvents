//
//  Pack.swift
//

import Foundation


// keeping these as standalone functions allows List/Record descriptors to provide optimized packing in common use cases (e.g. list of string); Q. can functions that take Data as argument operate on slices of an existing Data value? (i.e. we don't want to create an extra data copying step when iterating over a list desc); OTOH, we might want to wrap pairs of pack/unpack functions in 'Coercion' structs, as those can then provide additional features such as bounds checks and documentation generation (c.f. sylvia-lang; mostly it depends on how apps implement their server-side AE interfaces - if it's all code-generated then structs are redundant as the glue generator will produce both code and docs in parallel, and can just as easily generate introspection support; OTOH, if users write interface code directly then docs and introspection must driven by that; in an ideal world, the AE interface would be described in a sylvia-lang dialect, which then generates the Swift code, etc)


// TO DO: this is problematic as it requires unflattenDescriptor() to recognize AERecords with non-reco type and return them as RecordDescriptor, not ScalarDescriptor; e.g. an AERecord of type cDocument has the same layout as non-collection AEDescs of typeInteger/typeUTF8Text/etc, so how does AEIsRecord() tell the difference?


// public pack functions should always be of type `(T) -> Descriptor` (scalar); pack funcs that validate input values should also throw


public func packAsBool(_ value: Bool) -> ScalarDescriptor {
    return value ? trueDescriptor : falseDescriptor
}

public func packAsInt16(_ value: Int16) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeSInt16, data: encodeFixedWidthInteger(value))
}
public func packAsUInt16(_ value: UInt16) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeUInt16, data: encodeFixedWidthInteger(value))
}

public func packAsInt32(_ value: Int32) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeSInt32, data: encodeFixedWidthInteger(value))
}
public func packAsUInt32(_ value: UInt32) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeUInt32, data: encodeFixedWidthInteger(value))
}

public func packAsInt64(_ value: Int64) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeSInt64, data: encodeFixedWidthInteger(value))
}
public func packAsUInt64(_ value: UInt64) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeUInt64, data: encodeFixedWidthInteger(value))
}

public func packAsInt(_ value: Int) -> ScalarDescriptor { // caution: this always packs Int/UInt as typeSInt64/typeUInt64; this may break compatibility with poorly implemented apps that blindly expect typeSInt32 (because that's what AS gives them) instead of telling AEM that's what they need; while we could check if value falls within Int32.min…Int32.max and preferentially pack as typeSInt32, that's more work
    return packAsInt64(Int64(value))
}
public func packAsUInt(_ value: UInt) -> ScalarDescriptor { // ditto
    return packAsUInt64(UInt64(value))
}

public func packAsDouble(_ value: Double) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeIEEE64BitFloatingPoint, data: encodeFixedWidthValue(value))
}

public func packAsString(_ value: String) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeUTF8Text, data: encodeUTF8String(value))
}

public func packAsDate(_ value: Date) -> ScalarDescriptor {
    // caution: typeLongDateTime does not support sub-second precision; unfortunately, there isn't a desc type for TimeInterval (Double) since OSX epoch
    // TO DO: what about typeISO8601DateTime?
    return ScalarDescriptor(type: typeLongDateTime, data: encodeFixedWidthInteger(Int64(value.timeIntervalSinceReferenceDate - epochDelta)))
}

public func packAsFileURL(_ value: URL) throws -> ScalarDescriptor {
    // TO DO: option/initializer to create bookmark? (Q. how should bookmarks be supported?)
    // func bookmarkData(options: URL.BookmarkCreationOptions = [], includingResourceValuesForKeys keys: Set<URLResourceKey>? = nil, relativeTo url: URL? = nil) throws -> Data
    if !value.isFileURL { throw AppleEventError.unsupportedCoercion } // TO DO: what error?
    return ScalarDescriptor(type: typeFileURL, data: encodeUTF8String(value.absoluteString))
}

public func packAsFourCharCode(type: DescType, code: OSType) -> ScalarDescriptor { // other four-char codes // TO DO: this is not ideal as caller can freely pass invalid types; safer to define dedicated initializers for all relevant types
    return ScalarDescriptor(type: type, data: encodeUInt32(code))
}

public func packAsType(_ value: OSType) -> ScalarDescriptor {
    // TO DO: how should cMissingValue be handled? (not much we can do about it here, as it must pack)
    return ScalarDescriptor(type: typeType, data: encodeUInt32(value))
}

public func packAsEnum(_ value: OSType) -> ScalarDescriptor {
    // TO DO: should we check for absolute ordinal values and pack as typeAbsoluteOrdinal as special case? (mostly depends on whether they've any possible use cases outside of by-index specifiers, e.g. in introspection APIs [TBH, it shouldn't matter what type they are as long as by-index specifiers continue to be built using typeAbsoluteOrdinal]); TBH, we probably want to treat both typeType and typeEnumerated as interchangeable (there was never any obvious reason not to have a single AE desc type cover all OSTypes, and might well have avoided various bugs and other confusion when mapping human-readable names to and from four-char codes)
    return ScalarDescriptor(type: typeEnumerated, data: encodeUInt32(value))
}

public func packAsDescriptor(_ value: Descriptor) -> Descriptor {
    return value
}


// TO DO: delete packAsArray?

public func packAsArray<S: Sequence>(_ items: S, using packFunc: (S.Element) throws -> Descriptor) rethrows -> ListDescriptor {
    return try ListDescriptor(from: items, using: packFunc)
}

public func newPackArrayFunc<T>(using packFunc: @escaping (T) throws -> Descriptor) -> ([T]) throws -> Descriptor {
    return { try ListDescriptor(from: $0, using: packFunc) }
}


// TO DO: how best to compose pack/unpack/validate behaviors for AERecords? Swift's type system gets a tad twitchy when attempting to nest generic functions (also, where should user-defined record keys be handled? here, or in higher-level client code?)

/*
    try packAsRecord(self.lazy.map{ (key: Key, value: Value) -> (AEKeyword, Value) in
            if let key = key as? Symbol, key.code != noOSType { return (key.code, value) }
            throw AppleEventError.unsupportedCoercion
        }, using: appData.pack)
 */


public func packAsRecord<S: Sequence, T>(_ items: S, using packFunc: (T) throws -> Descriptor) throws -> RecordDescriptor
    where S.Element == (AEKeyword, T) {
        var result = Data()
        var count: UInt32 = 0
        var type = typeAERecord
        var keys = Set<AEKeyword>()
        for (key, value) in items {
            if keys.contains(key) {
                throw AppleEventError(code: -1704, message: "Can't pack item \(literalFourCharCode(key)) of record: duplicate key.")
            }
            keys.insert(key)
            do {
                let desc = try packFunc(value)
                if key == pClass, let cls = try? unpackAsType(desc) {
                    type = cls
                } else {
                    result += encodeUInt32(key)
                    desc.appendTo(containerData: &result)
                    count += 1
                }
            } catch {
                throw AppleEventError(message: "Can't pack item \(literalFourCharCode(key)) of record.", cause: error)
            }
        }
        return RecordDescriptor(type: type, count: count, data: result)
}

