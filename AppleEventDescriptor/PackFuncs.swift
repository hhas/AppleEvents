//
//  Pack.swift
//

import Foundation


// keeping these as standalone functions allows List/Record descriptors to provide optimized packing in common use cases (e.g. list of string); Q. can functions that take Data as argument operate on slices of an existing Data value? (i.e. we don't want to create an extra data copying step when iterating over a list desc); OTOH, we might want to wrap pairs of pack/unpack functions in 'Coercion' structs, as those can then provide additional features such as bounds checks and documentation generation (c.f. sylvia-lang; mostly it depends on how apps implement their server-side AE interfaces - if it's all code-generated then structs are redundant as the glue generator will produce both code and docs in parallel, and can just as easily generate introspection support; OTOH, if users write interface code directly then docs and introspection must driven by that; in an ideal world, the AE interface would be described in a sylvia-lang dialect, which then generates the Swift code, etc)



// public pack functions should always be of type `(T) -> Descriptor` (scalar); pack funcs that validate input values should also throw


public func packAsBool(_ value: Bool) -> ScalarDescriptor {
    return value ? trueDescriptor : falseDescriptor
}

public func packAsInt16(_ value: Int16) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeSInt16, data: packInteger(value))
}
public func packAsUInt16(_ value: UInt16) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeUInt16, data: packInteger(value))
}

public func packAsInt32(_ value: Int32) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeSInt32, data: packInteger(value))
}
public func packAsUInt32(_ value: UInt32) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeUInt32, data: packInteger(value))
}

public func packAsInt64(_ value: Int64) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeSInt64, data: packInteger(value))
}
public func packAsUInt64(_ value: UInt64) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeUInt64, data: packInteger(value))
}

public func packAsInt(_ value: Int) -> ScalarDescriptor { // caution: this always packs Int/UInt as typeSInt64/typeUInt64; this may break compatibility with poorly implemented apps that blindly expect typeSInt32 (because that's what AS gives them) instead of telling AEM that's what they need; while we could check if value falls within Int32.min…Int32.max and preferentially pack as typeSInt32, that's more work
    return packAsInt64(Int64(value))
}
public func packAsUInt(_ value: UInt) -> ScalarDescriptor { // ditto
    return packAsUInt64(UInt64(value))
}

public func packAsDouble(_ value: Double) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeIEEE64BitFloatingPoint, data: packFixedSize(value))
}

public func packAsString(_ value: String) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeUTF8Text, data: packUTF8String(value))
}

public func packAsDate(_ value: Date) -> ScalarDescriptor {
    // caution: typeLongDateTime does not support sub-second precision; unfortunately, there isn't a desc type for TimeInterval (Double) since OSX epoch
    // TO DO: what about typeISO8601DateTime?
    return ScalarDescriptor(type: typeLongDateTime, data: packInteger(Int64(value.timeIntervalSinceReferenceDate - epochDelta)))
}

public func packAsFileURL(_ value: URL) throws -> ScalarDescriptor {
    // TO DO: option/initializer to create bookmark? (Q. how should bookmarks be supported?)
    // func bookmarkData(options: URL.BookmarkCreationOptions = [], includingResourceValuesForKeys keys: Set<URLResourceKey>? = nil, relativeTo url: URL? = nil) throws -> Data
    if !value.isFileURL { throw AppleEventError.unsupportedCoercion } // TO DO: what error?
    return ScalarDescriptor(type: typeFileURL, data: packUTF8String(value.absoluteString))
}

public func packAsFourCharCode(type: DescType, code: OSType) -> ScalarDescriptor { // other four-char codes // TO DO: this is not ideal as caller can freely pass invalid types; safer to define dedicated initializers for all relevant types
    return ScalarDescriptor(type: type, data: packUInt32(code))
}

public func packAsType(_ value: OSType) -> ScalarDescriptor {
    // TO DO: how should cMissingValue be handled?
    return ScalarDescriptor(type: typeType, data: packUInt32(value))
}

public func packAsEnum(_ value: OSType) -> ScalarDescriptor {
    return ScalarDescriptor(type: typeEnumerated, data: packUInt32(value))
}


// TO DO: delete packAsArray?

public func packAsArray<S: Sequence>(_ items: S, using packFunc: (S.Element) throws -> Descriptor) rethrows -> ListDescriptor {
    return try ListDescriptor(from: items, using: packFunc)
}

public func newPackArrayFunc<T>(using packFunc: @escaping (T) throws -> Descriptor) -> ([T]) throws -> Descriptor {
    return { try ListDescriptor(from: $0, using: packFunc) }
}




public func packAsDictionary<T>(_ items: [AEKeyword: T], using packFunc: (T) throws -> Descriptor) throws -> Descriptor {
    // TO DO: this is problematic as it requires unflattenDescriptor() to recognize AERecords with non-reco type and return them as RecordDescriptor, not ScalarDescriptor; e.g. an AERecord of type cDocument has the same layout as non-collection AEDescs of typeInteger/typeUTF8Text/etc, so how does AEIsRecord() tell the difference?
    return try RecordDescriptor(from: items, using: packFunc)
}
