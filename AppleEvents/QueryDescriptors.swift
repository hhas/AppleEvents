//
//  QueryDescriptors.swift
//

import Foundation

// TO DO: also need unflatten() initializers (Q. how should this relate to unpack funcs?)


// TO DO: should unflatten methods also return final offset to caller so it can sanity check against expected dataEnd?

// TO DO: one disadvantage of using structs is that it makes caching more awkward; currently, the `data` attribute is calculated on each use, so queries are cheap to assemble but cost each time they're serialized; conversely, deserializing is expensive but working with the resulting structs' attributes is cheap (i.e. the current performance profile is more favorable to server-side use); constrast SwiftAutomation's class-based specifiers, which pack the descriptor on first use, then cache it for subsequent reuse (common in client-side code, where a single specifier may be used to derive many more); best solution is probably to leave client-side caching to SwiftAutomation specifiers (which will remain as class instances)


// TO DO: how best to unpack record properties? composable approach would require unpack funcs that take a single property key + unpack func; alternative is code generation (which has advantage of mapping to completed structs); composing multiple property unpackfuncs would mean that return value would be recursively nested tuple, which is a bit scary (chances are Swift'll explode upon trying to unroll it), or an Array<Any>, which loses the benefits of using Swift in the first place (wonder if this is the sort of challenge where derived types come into their own…but that's academic here)


// RootDescriptor (App, Con, Its, Custom)

// the following descriptors are traditionally constructed as an AERecord of custom type containing type-specific properties (though not necessarily in a fixed order); while it'd be faster and simpler to build objspecs as simple scalar descriptors (fixed order struct; no need for count or property keys), we need to remain backwards-compatible with traditional Apple events (although future implementations could offer a choice, enabling clients and servers that can use the newer streamlined types to request them via content negotiation); for now, we split the difference and build the descriptors directly rather than via Record APIs, although we still need to unpack them the slow(er) way as we cannot assume the property order of descriptors received from other sources

// ObjectSpecifierDescriptor
// MultipleObjectSpecifierDescriptor (ObjectSpecifierDescriptor with additional constructors)
// InsertionLocationDescriptor
// RangeDescriptor
// ComparisonDescriptor
// LogicDescriptor

// TO DO: unpackSpecifier function should probably take a callback/return an iterator, rather than returning a struct; that avoids unnecessary overheads when implementing server-side handling (no need to iterate twice, first to unpack objspec structs then to traverse them), and client-side too (we can save time on unpacking objspecs returned by app by only unpacking the topmost descriptor; the rest of the 'from' chain can be left packed and only unpacked if/when generating a display string)

// TO DO: need to decide which protocols are public and which are private; also need to decide on naming scheme (e.g. Foo vs FooProtocol vs FooDescriptor, bearing in mind that we're using protocols to compose public behavior)

// note that query dispatcher needs to be able to distinguish between single-object and multiple-object specifiers (single-object dispatch is usually easy to implement over conventional DOM-style model, as it forwards the operation to the target object [e.g. `get`/`set`] or its container [e.g. `move`/`copy`/`delete`] to perform; similarly, multiple-object specifiers can be dispatched the same way IF they are non-mutating [e.g. `get`/`count`]; the main gotchas when implementing an AEOM are 1. manipulating 'virtual' objects, e.g. `character`/`word`/`paragraph`, efficiently; and 2. performing mutating operations on multiple objects whose container is implemented as an ordered collection, e.g. Array); given an IDL/interface implementation that can precisely describe the Model's capabilities, we can determine which command+objspec combinations can operate on multi-object specifiers and which must be restricted to single-object specifiers (ideally, the IDL should contain enough info to enable full direct Siri voice control of applications, though obviously there's a lot of R&D to do before getting to that level)


// TO DO: make these AbsolutePosition, RelativePosition enums on ObjectSpecifierDescriptor

private let firstPosition   = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x66, 0x69, 0x72, 0x73])) // kAEFirst
private let middlePosition  = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x6D, 0x69, 0x64, 0x64])) // kAEMiddle
private let lastPosition    = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x6C, 0x61, 0x73, 0x74])) // kAELast
private let anyPosition     = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x61, 0x6E, 0x79, 0x20])) // kAEAny
private let allPosition     = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x61, 0x6C, 0x6C, 0x20])) // kAEAll

private let previousElement = ScalarDescriptor(type: typeEnumerated, data: Data([0x70, 0x72, 0x65, 0x76])) // kAEPrevious
private let nextElement     = ScalarDescriptor(type: typeEnumerated, data: Data([0x6E, 0x65, 0x78, 0x74])) // kAENext



public protocol SpecifierDescriptor: QueryDescriptor {
    
    // note: an enhanced AEOM could easily allow multiple properties to be retrieved per query by packing as AEList of typeType (the main challenge is finding a client-side syntax that works); what other behaviors could be improved (e.g. unborking not-equals and is-in tests; simplified query descriptor layouts)

    func userProperty(_ name: String) -> ObjectSpecifierDescriptor
    func property(_ code: OSType) -> ObjectSpecifierDescriptor
    func elements(_ code: OSType) -> MultipleObjectSpecifierDescriptor
}

public extension SpecifierDescriptor {
    
    func userProperty(_ name: String) -> ObjectSpecifierDescriptor {
        return ObjectSpecifierDescriptor(want: typeProperty, form: .userProperty, seld: packAsString(name), from: self)
    }
    
    func property(_ code: OSType) -> ObjectSpecifierDescriptor {
        return ObjectSpecifierDescriptor(want: typeProperty, form: .property, seld: packAsType(code), from: self)
    }
    
    func elements(_ code: OSType) -> MultipleObjectSpecifierDescriptor {
        return MultipleObjectSpecifierDescriptor(want: code, form: .absolutePosition, seld: allPosition, from: self)
    }
}


// base objects from which queries are constructed

public struct RootSpecifierDescriptor: SpecifierDescriptor { // abstract wrapper for the terminal descriptor in an object specifier; like a single-object specifier it exposes methods for constructing property and all-elements specifiers, e.g. `RootSpecifierDescriptor.app.elements(cDocument)`, `RootSpecifierDescriptor.its.property(pName)`
    
    public static let app = RootSpecifierDescriptor(nullDescriptor)
    public static let con = RootSpecifierDescriptor(ScalarDescriptor(type: typeCurrentContainer, data: nullData))
    public static let its = RootSpecifierDescriptor(ScalarDescriptor(type: typeObjectBeingExamined, data: nullData))

    
    public var type: DescType { return self.descriptor.type }
    public var data: Data { return self.descriptor.data }
    
    public var from: QueryDescriptor { return self } // TO DO: rename `parent`?
    
    internal let descriptor: Descriptor // while atypical, it is possible for an object specifier to have any 'from' value, e.g. `folders of alias "…"` is undocumented but legal in Finder; whether we continue to support this or start to lock down to a sensible spec is TBC (e.g. in Finder, that query can be rewritten as `folders of item (alias "…")`, which at least tickles a different bit of the spec); presumably this flexibility in legal chunk expressions is, in part, to permit constructing queries over AppleScript types (in which case the ability to serialize those queries as AEs is simply undocumented behavior left open), although it may also be deliberate precisely to allow more "English-like" phrasing when dealing with apps such as Finder that are capable of interpreting aliases and other primitive specifier types (i.e. 'folders of alias…' reads better than 'folders of item alias…', although it goes without saying that such 'magical' behaviors end up creating as much consistency/learnability hell)
    
    public init(_ descriptor: Descriptor) {
        self.descriptor = descriptor
    }
    
    public func flatten() -> Data {
        return self.descriptor.flatten()
    }
    
    public func appendTo(containerData result: inout Data) {
        self.descriptor.appendTo(containerData: &result)
    }
}


// insertion location, e.g. `beginning of ELEMENTS`, `after ELEMENT`

public struct InsertionLocationDescriptor: QueryDescriptor {
    
    public var debugDescription: String {
        return "<\(Swift.type(of: self)) \(self.position) \(self.from)>"
    }
    
    public enum Position: OSType, CustomDebugStringConvertible {
        case before     = 0x6265666F // kAEBefore
        case after      = 0x61667465 // kAEAfter
        case beginning  = 0x62676E67 // kAEBeginning
        case end        = 0x656E6420 // kAEEnd
        
        public var debugDescription: String {
            switch self {
            case .before:    return ".before"
            case .after:     return ".after"
            case .beginning: return ".beginning"
            case .end:       return ".end"
            }
        }
    }
    
    public let type: DescType = typeInsertionLoc
    
    public var data: Data {
        var result = Data([0x00, 0x00, 0x00, 0x02,      // count (position, object)
            0, 0, 0, 0,                  // align
            0x6B, 0x70, 0x6F, 0x73,      // * keyAEPosition
            0x65, 0x6E, 0x75, 0x6D,      //   typeEnumerated
            0x00, 0x00, 0x00, 0x04])     //   size (4 bytes)
        result += encodeUInt32(self.position.rawValue)    //   enum code
        result += Data([0x6B, 0x6F, 0x62, 0x6A])        // * keyAEObject
        self.from.appendTo(containerData: &result)      //   descriptor
        return result
    }
    
    public let position: Position
    public let from: QueryDescriptor
    
    public init(position: Position, from: QueryDescriptor) {
        self.position = position
        self.from = from
    }
    
    // called by Unflatten.swift
    internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> InsertionLocationDescriptor {
        // type, remaining bytes // TO DO: sanity check these?
        var position: OSType? = nil, from: QueryDescriptor? = nil
        let countOffset = descStart + 8
        if data.readUInt32(at: countOffset) != 2 { throw AppleEventError.invalidParameterCount }
        var offset = countOffset + 8
        for _ in 0..<2 {
            let key = data[offset..<(offset+4)]
            switch key {
            case Data([0x6B, 0x70, 0x6F, 0x73])                                         // * keyAEPosition
                where data[(offset+4)..<(offset+12)] == Data([0x65, 0x6E, 0x75, 0x6D,   //   typeEnumerated
                    0x00, 0x00, 0x00, 0x04]): //   size (4 bytes)
                position = data.readUInt32(at: offset+12)
                offset += 16
            case Data([0x6B, 0x6F, 0x62, 0x6A]):                                        // * keyAEObject
                let desc: Descriptor                                                    //   QueryDescriptor
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                // object specifier's parent is either an object specifier or its terminal [root] descriptor
                from = (desc.type == typeObjectSpecifier) ? (desc as! QueryDescriptor) : RootSpecifierDescriptor(desc) // TO DO: could do with utility functions that cast to expected type and return or throw 'corrupt data' or 'internal error' (i.e. bug); alternatively, might build this into unflattenFirstDescriptor(), with return type being Descriptor (the default) or the expected FOODescriptor type
            default:
                throw AppleEventError.invalidParameter
            }
        }
        guard let position_ = position, let from_ = from, let position__ = Position(rawValue: position_) else {
            throw AppleEventError.invalidParameter
        }
        return InsertionLocationDescriptor(position: position__, from: from_)
    }
}


// object specifier, e.g. `PROPERTY of …`, `every ELEMENT of …`, `ELEMENT INDEX of …`, `(ELEMENTS where TEST) of …`

public struct ObjectSpecifierDescriptor: SpecifierDescriptor { // TO DO: want to reuse this implementation in MultipleObjectSpecifierDescriptor
    
    public var debugDescription: String {
        return "<\(Swift.type(of: self)) \(literalFourCharCode(self.want)) \(self.form) \(self.seld) \(self.from)>"
    }
    
    // TO DO: combine form+seld? (in practice, this may be of limited value as a degree of sloppiness is necessary to ensure backwards compatibility with existing ecosystem, but it might help clarify usage)
    public enum Form: OSType, CustomDebugStringConvertible {
        case property           = 0x70726F70
        case absolutePosition   = 0x696E6478
        case name               = 0x6E616D65
        case uniqueID           = 0x49442020
        case relativePosition   = 0x72656C65
        case range              = 0x72616E67
        case test               = 0x74657374
        case userProperty       = 0x75737270
        
        public var debugDescription: String {
            switch self {
            case .property:         return ".property"
            case .absolutePosition: return ".absolutePosition"
            case .name:             return ".name"
            case .uniqueID:         return ".uniqueID"
            case .relativePosition: return ".relativePosition"
            case .range:            return ".range"
            case .test:             return ".test"
            case .userProperty:     return ".userProperty"
            }
        }
    }
    
    public let type: DescType = typeObjectSpecifier
    
    // TO DO: naming?
    public let want: DescType
    public let form: ObjectSpecifierDescriptor.Form
    public let seld: Descriptor // may be anything
    public let from: QueryDescriptor // (objspec or root; technically it can be anything, but if we define a dedicated QueryRoot struct then we can put appropriate constructors on that)
    
    public init(want: DescType, form: ObjectSpecifierDescriptor.Form, seld: Descriptor, from: QueryDescriptor) {
        self.want = want
        self.form = form
        self.seld = seld
        self.from = from
    }
    
    public var data: Data {
        // flatten()/appendTo() will prefix type, remaining bytes
        var result = Data([0x00, 0x00, 0x00, 0x04,  // count (want, form, data, from)
                           0, 0, 0, 0,              // align
                           0x77, 0x61, 0x6E, 0x74,  // * keyAEDesiredClass
                           0x74, 0x79, 0x70, 0x65,  //   typeType
                           0x00, 0x00, 0x00, 0x04]) //   size (4 bytes)
        result += encodeUInt32(self.want)             //   type code
        result += Data([0x66, 0x6F, 0x72, 0x6D,     // * keyAEKeyForm
                        0x65, 0x6E, 0x75, 0x6D,     //   typeEnumerated
                        0x00, 0x00, 0x00, 0x04])    //   size (4 bytes)
        result += encodeUInt32(self.form.rawValue)    //   enum code
        result += Data([0x73, 0x65, 0x6C, 0x64])    // * keyAEKeyData
        self.seld.appendTo(containerData: &result)  //   descriptor
        result += Data([0x66, 0x72, 0x6F, 0x6D])    // * keyAEContainer
        self.from.appendTo(containerData: &result)  //   descriptor
        return result
    }
    
    // called by Unflatten.swift
    internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> ObjectSpecifierDescriptor {
        // type, remaining bytes // TO DO: sanity check these?
        var want: OSType? = nil, form: OSType? = nil, seld: Descriptor? = nil, from: QueryDescriptor? = nil
        let countOffset = descStart + 8 // while typeObjectSpecifier is nominally an AERecord, it lacks the extra padding between bytes remaining and number of items found in typeAERecord
        if data.readUInt32(at: countOffset) != 4 { throw AppleEventError.invalidParameterCount }
        var offset = countOffset + 8
        for _ in 0..<4 {
            let key = data[offset..<(offset+4)]
            switch key {
            case Data([0x77, 0x61, 0x6E, 0x74])                                         // * keyAEDesiredClass
                where data[(offset+4)..<(offset+12)] == Data([0x74, 0x79, 0x70, 0x65,   //   typeType
                                                              0x00, 0x00, 0x00, 0x04]): //   size (4 bytes)
                want = data.readUInt32(at: offset+12)                                   //   type code
                offset += 16
            case Data([0x66, 0x6F, 0x72, 0x6D])                                         // * keyAEKeyForm
                where data[(offset+4)..<(offset+12)] == Data([0x65, 0x6E, 0x75, 0x6D,   //   typeEnumerated
                                                              0x00, 0x00, 0x00, 0x04]): //   size (4 bytes)
                form = data.readUInt32(at: offset+12)
                offset += 16
            case Data([0x73, 0x65, 0x6C, 0x64]):                                        // * keyAEKeyData
                let desc: Descriptor                                                    //   any Descriptor
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                seld = desc
            case Data([0x66, 0x72, 0x6F, 0x6D]):                                        // * keyAEContainer
                // TO DO: how best to implement lazy unpacking for client-side use? (i.e. when an app returns an obj spec, only the topmost specifier needs unwrapped in order to be used; the remainder can be left in an opaque wrapper similar to RootSpecifierDescriptor and only fully unpacked when needed, e.g. when constructing specifier's display representation); this can measurably improve performance where an application command returns a large list of specifiers
                let desc: Descriptor                                                    //   QueryDescriptor
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                // object specifier's parent is either another object specifier or its terminal [root] descriptor
                from = (desc.type == typeObjectSpecifier) ? (desc as! QueryDescriptor) : RootSpecifierDescriptor(desc)
            default:
                throw AppleEventError.invalidParameter
            }
        }
        guard let want_ = want, let form_ = form, let seld_ = seld, let from_ = from,
            let selform = Form(rawValue: form_) else {
                throw AppleEventError.invalidParameter
        }
        return ObjectSpecifierDescriptor(want: want_, form: selform, seld: seld_, from: from_)
    }
}


public extension ObjectSpecifierDescriptor {
    
    // TO DO: SA also exposes the following on Root specifiers
    
    // relative position selectors
    func previous(_ code: OSType? = nil) -> ObjectSpecifierDescriptor {
        return ObjectSpecifierDescriptor(want: code ?? self.want, form: .relativePosition, seld: previousElement, from: self)
    }
     
    func next(_ code: OSType? = nil) -> ObjectSpecifierDescriptor {
        return ObjectSpecifierDescriptor(want: code ?? self.want, form: .relativePosition, seld: nextElement, from: self)
    }
    
    // insertion specifiers
    // TO DO: AppleScript/CocoaScripting does allow `beginning/end/etc [of app]` as abbreviated `beginning/end/etc [of elements of app]` where element type can be inferred (e.g. `make new document at beginning with properties {…}`); for API equivalence the following would need to be exposed on RootSpecifierDescriptor as well
    
    var beginning: InsertionLocationDescriptor {
        return InsertionLocationDescriptor(position: .beginning, from: self)
    }
    var end: InsertionLocationDescriptor {
        return InsertionLocationDescriptor(position: .end, from: self)
    }
    var before: InsertionLocationDescriptor {
        return InsertionLocationDescriptor(position: .before, from: self)
    }
    var after: InsertionLocationDescriptor {
        return InsertionLocationDescriptor(position: .after, from: self)
    }
}


public typealias MultipleObjectSpecifierDescriptor = ObjectSpecifierDescriptor // TO DO: temporary, until we decide how best to 'subclass' ObjectSpecifierDescriptor


public extension MultipleObjectSpecifierDescriptor {
    
    struct RangeDescriptor: Scalar {
        
        public let type: DescType = typeRangeDescriptor
        
        public var data: Data {
            var result = Data([0x00, 0x00, 0x00, 0x02,      // count (start, stop)
                               0, 0, 0, 0,                  // align
                               0x73, 0x74, 0x61, 0x72])     // * keyAERangeStart
            self.start.appendTo(containerData: &result)     //   descriptor
            result += Data([0x73, 0x74, 0x6F, 0x70])        // * keyAERangeStop
            self.stop.appendTo(containerData: &result)      //   descriptor
            return result
        }
        
        // TO DO: should initializers accept Int/String as shorthand for RootSpecifierDescriptor.con.elements(TYPE).byIndex(INT)/.byName(STRING), or should that be dealt with upstream? (probably upstream, as RangeDescriptor does not inherently know what the element TYPE is)
        
        public let start: QueryDescriptor // should always be QueryDescriptor; root is either Con or App (con is standard; not sure we can discount absolute specifiers though)
        public let stop: QueryDescriptor // should always be QueryDescriptor
        
        public init(start: QueryDescriptor, stop: QueryDescriptor) {
            self.start = start
            self.stop = stop
        }
        
        internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> RangeDescriptor {
            // type, remaining bytes // TO DO: sanity check these?
            var start: QueryDescriptor? = nil, stop: QueryDescriptor? = nil
            let countOffset = descStart + 8
            if data.readUInt32(at: countOffset) != 2 { throw AppleEventError.invalidParameterCount }
            var offset = countOffset + 8
            for _ in 0..<2 {
                let key = data[offset..<(offset+4)]
                switch key {
                case Data([0x73, 0x74, 0x61, 0x72]):                                        // * keyAERangeStart
                    let desc: Descriptor                                                    //   QueryDescriptor
                    (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                    // object specifier's parent is either an object specifier or its terminal [root] descriptor
                    start = (desc.type == typeObjectSpecifier) ? (desc as! QueryDescriptor) : nil
                case Data([0x73, 0x74, 0x6F, 0x70]):                                        // * keyAERangeStop
                    let desc: Descriptor                                                    //   QueryDescriptor
                    (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                    // object specifier's parent is either an object specifier or its terminal [root] descriptor
                    stop = (desc.type == typeObjectSpecifier) ? (desc as! QueryDescriptor) : nil
                default:
                    throw AppleEventError.invalidParameter
                }
            }
            guard let start_ = start, let stop_ = stop else {
                throw AppleEventError.invalidParameter
            }
            return RangeDescriptor(start: start_, stop: stop_)
        }
    }
    
    private var baseQuery: QueryDescriptor { // discards the default kAEAll selector when calling an element[s] selector on `elements(TYPE)`
        return self.form == .absolutePosition && (try? unpackAsEnum(self.seld)) == OSType(kAEAll) ? self.from : self
    }
    
    func byIndex(_ index: Descriptor) -> ObjectSpecifierDescriptor { // TO DO: also accept Int for convenience?
        return ObjectSpecifierDescriptor(want: self.want, form: .absolutePosition, seld: index, from: self.baseQuery)
    }
    func byName(_ name: Descriptor) -> ObjectSpecifierDescriptor { // TO DO: take Descriptor instead of/as well as String?
        return ObjectSpecifierDescriptor(want: self.want, form: .name, seld: name, from: self.baseQuery)
    }
    func byID(_ id: Descriptor) -> ObjectSpecifierDescriptor {
        return ObjectSpecifierDescriptor(want: self.want, form: .uniqueID, seld: id, from: self.baseQuery)
    }
    func byRange(from start: QueryDescriptor, to stop: QueryDescriptor) -> MultipleObjectSpecifierDescriptor {
        // TO DO: start/stop should always be absolute/container-based query; how best to implement? (if we allow passing Int/String descriptors here, RangeDescriptor needs to build the container specifiers)
        return MultipleObjectSpecifierDescriptor(want: self.want, form: .range,
                                       seld: RangeDescriptor(start: start, stop: stop), from: self.baseQuery)
    }
    func byTest(_ test: TestDescriptor) -> MultipleObjectSpecifierDescriptor {
        return MultipleObjectSpecifierDescriptor(want: self.want, form: .test, seld: test, from: self.baseQuery)
    }
    
    var first: ObjectSpecifierDescriptor {
        return ObjectSpecifierDescriptor(want: self.want, form: .absolutePosition, seld: firstPosition, from: self.baseQuery)
    }
    var middle: ObjectSpecifierDescriptor {
        return ObjectSpecifierDescriptor(want: self.want, form: .absolutePosition, seld: middlePosition, from: self.baseQuery)
    }
    var last: ObjectSpecifierDescriptor {
        return ObjectSpecifierDescriptor(want: self.want, form: .absolutePosition, seld: lastPosition, from: self.baseQuery)
    }
    var any: ObjectSpecifierDescriptor {
        return ObjectSpecifierDescriptor(want: self.want, form: .absolutePosition, seld: anyPosition, from: self.baseQuery)
    }
}


public extension ObjectSpecifierDescriptor {

    // Comparison test constructors
    
    static func <(lhs: ObjectSpecifierDescriptor, rhs: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: lhs, comparison: .lessThan, value: rhs)
    }
    static func <=(lhs: ObjectSpecifierDescriptor, rhs: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: lhs, comparison: .lessThanOrEqual, value: rhs)
    }
    static func ==(lhs: ObjectSpecifierDescriptor, rhs: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: lhs, comparison: .equal, value: rhs)
    }
    static func !=(lhs: ObjectSpecifierDescriptor, rhs: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: lhs, comparison: .notEqual, value: rhs)
    }
    static func >(lhs: ObjectSpecifierDescriptor, rhs: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: lhs, comparison: .greaterThan, value: rhs)
    }
    static func >=(lhs: ObjectSpecifierDescriptor, rhs: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: lhs, comparison: .greaterThanOrEqual, value: rhs)
    }
    
    // Containment test constructors
    
    // note: ideally the following would only appear on objects constructed from an Its root; however, this would complicate the implementation while failing to provide any real benefit to users, who are unlikely to make such a mistake in the first place
    
    func beginsWith(_ value: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: self, comparison: .beginsWith, value: value)
    }
    func endsWith(_ value: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: self, comparison: .endsWith, value: value)
    }
    func contains(_ value: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: self, comparison: .contains, value: value)
    }
    func isIn(_ value: Descriptor) -> TestDescriptor {
        return ComparisonDescriptor(object: self, comparison: .isIn, value: value)
    }
}


