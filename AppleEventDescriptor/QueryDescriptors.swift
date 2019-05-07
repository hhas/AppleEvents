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

// ObjectSpecifier
// MultipleObjectSpecifier (ObjectSpecifier with additional constructors)
// InsertionLocation
// RangeDescriptor
// ComparisonDescriptor
// LogicDescriptor

// TO DO: unpackSpecifier function should probably take a callback/return an iterator, rather than returning a struct; that avoids unnecessary overheads when implementing server-side handling (no need to iterate twice, first to unpack objspec structs then to traverse them), and client-side too (we can save time on unpacking objspecs returned by app by only unpacking the topmost descriptor; the rest of the 'from' chain can be left packed and only unpacked if/when generating a display string)

// TO DO: need to decide which protocols are public and which are private; also need to decide on naming scheme (e.g. Foo vs FooProtocol vs FooDescriptor, bearing in mind that we're using protocols to compose public behavior)

// note that query dispatcher needs to be able to distinguish between single-object and multiple-object specifiers (single-object dispatch is usually easy to implement over conventional DOM-style model, as it forwards the operation to the target object [e.g. `get`/`set`] or its container [e.g. `move`/`copy`/`delete`] to perform; similarly, multiple-object specifiers can be dispatched the same way IF they are non-mutating [e.g. `get`/`count`]; the main gotchas when implementing an AEOM are 1. manipulating 'virtual' objects, e.g. `character`/`word`/`paragraph`, efficiently; and 2. performing mutating operations on multiple objects whose container is implemented as an ordered collection, e.g. Array); given an IDL/interface implementation that can precisely describe the Model's capabilities, we can determine which command+objspec combinations can operate on multi-object specifiers and which must be restricted to single-object specifiers (ideally, the IDL should contain enough info to enable full direct Siri voice control of applications, though obviously there's a lot of R&D to do before getting to that level)



private let firstPosition   = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x66, 0x69, 0x72, 0x73])) // kAEFirst
private let middlePosition  = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x6D, 0x69, 0x64, 0x64])) // kAEMiddle
private let lastPosition    = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x6C, 0x61, 0x73, 0x74])) // kAELast
private let anyPosition     = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x61, 0x6E, 0x79, 0x20])) // kAEAny
private let allPosition     = ScalarDescriptor(type: typeAbsoluteOrdinal, data: Data([0x61, 0x6C, 0x6C, 0x20])) // kAEAll

private let previousElement = ScalarDescriptor(type: typeEnumerated, data: Data([0x70, 0x72, 0x65, 0x76])) // kAEPrevious
private let nextElement     = ScalarDescriptor(type: typeEnumerated, data: Data([0x6E, 0x65, 0x78, 0x74])) // kAENext





public struct RootSpecifier: Query { // abstract wrapper for the terminal descriptor in an object specifier; like a single-object specifier it exposes methods for constructing property and all-elements specifiers, e.g. `applicationRoot.elements(cDocument)`, `testSelectorRoot.property(pName)`
    
    public var type: DescType { return self.from.type }
    public var data: Data { return self.from.data }
    
    internal let from: Descriptor // while atypical, it is possible for an object specifier to have any 'from' value, e.g. `folders of alias "…"` is undocumented but legal in Finder; whether we continue to support this or start to lock down to a sensible spec is TBC (e.g. in Finder, that query can be rewritten as `folders of item (alias "…")`, which at least tickles a different bit of the spec); presumably this flexibility in legal chunk expressions is, in part, to permit constructing queries over AppleScript types (in which case the ability to serialize those queries as AEs is simply undocumented behavior left open), although it may also be deliberate precisely to allow more "English-like" phrasing when dealing with apps such as Finder that are capable of interpreting aliases and other primitive specifier types (i.e. 'folders of alias…' reads better than 'folders of item alias…', although it goes without saying that such 'magical' behaviors end up creating as much consistency/learnability hell)
    
    public func flatten() -> Data {
        return self.from.flatten()
    }
    
    public func appendTo(containerData result: inout Data) {
        self.from.appendTo(containerData: &result)
    }
}


public extension RootSpecifier {
    
    func userProperty(_ name: String) -> ObjectSpecifier {
        return ObjectSpecifier(want: typeProperty, form: .userProperty, seld: packAsString(name), from: self)
    }
    
    func property(_ code: OSType) -> ObjectSpecifier {
        return ObjectSpecifier(want: typeProperty, form: .property, seld: packAsType(code), from: self)
    }
    
    func elements(_ code: OSType) -> ObjectSpecifier { // TO DO: MultipleObjectSpecifier
        return ObjectSpecifier(want: code, form: .absolutePosition, seld: allPosition, from: self)
    }
}


let applicationRoot = RootSpecifier(from: nullDescriptor)
let rangeSelectorRoot = RootSpecifier(from: ScalarDescriptor(type: typeCurrentContainer, data: nullData))
let testSelectorRoot = RootSpecifier(from: ScalarDescriptor(type: typeObjectBeingExamined, data: nullData))




public struct ObjectSpecifier: Query { // TO DO: want to reuse this implementation in MultipleObjectSpecifier
    
    public enum Selector: OSType {
        case property           = 0x70726F70
        case absolutePosition   = 0x696E6478
        case name               = 0x6E616D65
        case uniqueID           = 0x49442020
        case relativePosition   = 0x72656C65
        case range              = 0x72616E67
        case test               = 0x74657374
        case userProperty       = 0x75737270
    }
    
    public let type: DescType = typeObjectSpecifier
    
    public let want: DescType
    public let form: Selector
    public let seld: Descriptor // may be anything
    public let from: Query // (objspec or root; technically it can be anything, but if we define a dedicated QueryRoot struct then we can put appropriate constructors on that)
    
    public var data: Data {
        // flatten()/appendTo() will prefix type, remaining bytes
        var result = Data([0x00, 0x00, 0x00, 0x04,  // count (want, form, data, from)
                           0, 0, 0, 0,              // align
                           0x77, 0x61, 0x6E, 0x74,  // * keyAEDesiredClass
                           0x74, 0x79, 0x70, 0x65,  //   typeType
                           0x00, 0x00, 0x00, 0x04]) //   size (4 bytes)
        result += packUInt32(self.want)             //   type code
        result += Data([0x66, 0x6F, 0x72, 0x6D,     // * keyAEKeyForm
                        0x65, 0x6E, 0x75, 0x6D,     //   typeEnumerated
                        0x00, 0x00, 0x00, 0x04])    //   size (4 bytes)
        result += packUInt32(self.form.rawValue)    //   enum code
        result += Data([0x73, 0x65, 0x6C, 0x64])    // * keyAEKeyData
        self.seld.appendTo(containerData: &result)  //   descriptor
        result += Data([0x66, 0x72, 0x6F, 0x6D])    // * keyAEContainer
        self.from.appendTo(containerData: &result)  //   descriptor
        return result
    }
    
    // called by Unflatten.swift
    internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> ObjectSpecifier {
        // type, remaining bytes // TO DO: sanity check these?
        var want: OSType? = nil, form: OSType? = nil, seld: Descriptor? = nil, from: Query? = nil
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
                // TO DO: how best to implement lazy unpacking for client-side use? (i.e. when an app returns an obj spec, only the topmost specifier needs unwrapped in order to be used; the remainder can be left in an opaque wrapper similar to RootSpecifier and only fully unpacked when needed, e.g. when constructing specifier's display representation); this can measurably improve performance where an application command returns a large list of specifiers
                let desc: Descriptor                                                    //   Query
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                // object specifier's parent is either another object specifier or its terminal [root] descriptor
                from = (desc.type == typeObjectSpecifier) ? (desc as! Query) : RootSpecifier(from: desc)
            default:
                throw AppleEventError.invalidParameter
            }
        }
        guard let want_ = want, let form_ = form, let seld_ = seld, let from_ = from,
            let selform = Selector(rawValue: form_) else {
                throw AppleEventError.invalidParameter
        }
        return ObjectSpecifier(want: want_, form: selform, seld: seld_, from: from_)
    }
}


public extension ObjectSpecifier {
    
    // the following are also implemented on Root specifier; Q. is it worth using protocols to mixin? (hardly seems worth it)
    
    func userProperty(_ name: String) -> ObjectSpecifier {
        return ObjectSpecifier(want: typeProperty, form: .userProperty, seld: packAsString(name), from: self)
    }
    
    // note: an enhanced AEOM could easily allow multiple properties to be retrieved per query by packing as AEList of typeType (the main challenge is finding a client-side syntax that works); what other behaviors could be improved (e.g. unborking not-equals and is-in tests; simplified query descriptor layouts)
    
    func property(_ code: OSType) -> ObjectSpecifier {
        return ObjectSpecifier(want: typeProperty, form: .property, seld: packAsType(code), from: self)
    }
    
    func elements(_ code: OSType) -> MultipleObjectSpecifier {
        return MultipleObjectSpecifier(want: code, form: .absolutePosition, seld: allPosition, from: self)
    }
    
    // TO DO: SA also exposes the following on Root specifiers
    
    // relative position selectors
    func previous(_ code: OSType? = nil) -> ObjectSpecifier {
        return ObjectSpecifier(want: code ?? self.want, form: .relativePosition, seld: previousElement, from: self)
    }
     
    func next(_ code: OSType? = nil) -> ObjectSpecifier {
        return ObjectSpecifier(want: code ?? self.want, form: .relativePosition, seld: nextElement, from: self)
    }
    
    // insertion specifiers
    // TO DO: AppleScript/CocoaScripting does allow `beginning/end/etc [of app]` as abbreviated `beginning/end/etc [of elements of app]` where element type can be inferred (e.g. `make new document at beginning with properties {…}`); for API equivalence the following would need to be exposed on RootSpecifier as well
    
    var beginning: InsertionLocation {
        return InsertionLocation(position: .beginning, from: self)
    }
    var end: InsertionLocation {
        return InsertionLocation(position: .end, from: self)
    }
    var before: InsertionLocation {
        return InsertionLocation(position: .before, from: self)
    }
    var after: InsertionLocation {
        return InsertionLocation(position: .after, from: self)
    }
}


public typealias MultipleObjectSpecifier = ObjectSpecifier // TO DO: temporary, until we decide how best to 'subclass' ObjectSpecifier


public extension MultipleObjectSpecifier {
    
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
        
        // TO DO: should initializers accept Int/String as shorthand for rangeSelectorRoot.elements(TYPE).byIndex(INT)/.byName(STRING), or should that be dealt with upstream? (probably upstream, as RangeDescriptor does not inherently know what the element TYPE is)
        
        public let start: Query // should always be Query; root is either Con or App (con is standard; not sure we can discount absolute specifiers though)
        public let stop: Query // should always be Query
        
        internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> RangeDescriptor {
            // type, remaining bytes // TO DO: sanity check these?
            var start: Query? = nil, stop: Query? = nil
            let countOffset = descStart + 8
            if data.readUInt32(at: countOffset) != 2 { throw AppleEventError.invalidParameterCount }
            var offset = countOffset + 8
            for _ in 0..<2 {
                let key = data[offset..<(offset+4)]
                switch key {
                case Data([0x73, 0x74, 0x61, 0x72]):                                        // * keyAERangeStart
                    let desc: Descriptor                                                    //   Query
                    (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                    // object specifier's parent is either an object specifier or its terminal [root] descriptor
                    start = (desc.type == typeObjectSpecifier) ? (desc as! Query) : nil
                case Data([0x73, 0x74, 0x6F, 0x70]):                                        // * keyAERangeStop
                    let desc: Descriptor                                                    //   Query
                    (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                    // object specifier's parent is either an object specifier or its terminal [root] descriptor
                    stop = (desc.type == typeObjectSpecifier) ? (desc as! Query) : nil
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
    
    private var baseQuery: Query { // discards the default kAEAll selector when calling an element[s] selector on `elements(TYPE)`
        return self.form == .absolutePosition && (try? unpackAsEnum(self.seld)) == kAEAll ? self.from : self
    }
    
    func byIndex(_ index: Descriptor) -> ObjectSpecifier { // TO DO: also accept Int for convenience?
        return ObjectSpecifier(want: self.want, form: .absolutePosition, seld: index, from: self.baseQuery)
    }
    func byName(_ name: Descriptor) -> ObjectSpecifier { // TO DO: take Descriptor instead of/as well as String?
        return ObjectSpecifier(want: self.want, form: .name, seld: name, from: self.baseQuery)
    }
    func byID(_ id: Descriptor) -> ObjectSpecifier {
        return ObjectSpecifier(want: self.want, form: .uniqueID, seld: id, from: self.baseQuery)
    }
    func byRange(from start: Query, to stop: Query) -> MultipleObjectSpecifier {
        // TO DO: start/stop should always be absolute/container-based query; how best to implement? (if we allow passing Int/String descriptors here, RangeDescriptor needs to build the container specifiers)
        return MultipleObjectSpecifier(want: self.want, form: .range,
                                       seld: RangeDescriptor(start: start, stop: stop), from: self.baseQuery)
    }
    func byTest(_ test: Test) -> MultipleObjectSpecifier {
        return MultipleObjectSpecifier(want: self.want, form: .test, seld: test, from: self.baseQuery)
    }
    
    var first: ObjectSpecifier {
        return ObjectSpecifier(want: self.want, form: .absolutePosition, seld: firstPosition, from: self.baseQuery)
    }
    var middle: ObjectSpecifier {
        return ObjectSpecifier(want: self.want, form: .absolutePosition, seld: middlePosition, from: self.baseQuery)
    }
    var last: ObjectSpecifier {
        return ObjectSpecifier(want: self.want, form: .absolutePosition, seld: lastPosition, from: self.baseQuery)
    }
    var any: ObjectSpecifier {
        return ObjectSpecifier(want: self.want, form: .absolutePosition, seld: anyPosition, from: self.baseQuery)
    }
}


public extension ObjectSpecifier {

    // Comparison test constructors
    
    static func <(lhs: ObjectSpecifier, rhs: Descriptor) -> Test {
        return ComparisonDescriptor(object: lhs, comparison: .lessThan, value: rhs)
    }
    static func <=(lhs: ObjectSpecifier, rhs: Descriptor) -> Test {
        return ComparisonDescriptor(object: lhs, comparison: .lessThanOrEqual, value: rhs)
    }
    static func ==(lhs: ObjectSpecifier, rhs: Descriptor) -> Test {
        return ComparisonDescriptor(object: lhs, comparison: .equal, value: rhs)
    }
    static func !=(lhs: ObjectSpecifier, rhs: Descriptor) -> Test {
        return ComparisonDescriptor(object: lhs, comparison: .notEqual, value: rhs)
    }
    static func >(lhs: ObjectSpecifier, rhs: Descriptor) -> Test {
        return ComparisonDescriptor(object: lhs, comparison: .greaterThan, value: rhs)
    }
    static func >=(lhs: ObjectSpecifier, rhs: Descriptor) -> Test {
        return ComparisonDescriptor(object: lhs, comparison: .greaterThanOrEqual, value: rhs)
    }
    
    // Containment test constructors
    
    // note: ideally the following would only appear on objects constructed from an Its root; however, this would complicate the implementation while failing to provide any real benefit to users, who are unlikely to make such a mistake in the first place
    
    func beginsWith(_ value: Descriptor) -> Test {
        return ComparisonDescriptor(object: self, comparison: .beginsWith, value: value)
    }
    func endsWith(_ value: Descriptor) -> Test {
        return ComparisonDescriptor(object: self, comparison: .endsWith, value: value)
    }
    func contains(_ value: Descriptor) -> Test {
        return ComparisonDescriptor(object: self, comparison: .contains, value: value)
    }
    func isIn(_ value: Descriptor) -> Test {
        return ComparisonDescriptor(object: self, comparison: .isIn, value: value)
    }
}







public struct InsertionLocation: Query {

    public enum Position: OSType {
        case before     = 0x6265666F // kAEBefore
        case after      = 0x61667465 // kAEAfter
        case beginning  = 0x62676E67 // kAEBeginning
        case end        = 0x656E6420 // kAEEnd
    }
    public let type: DescType = typeInsertionLoc
    
    public var data: Data {
        var result = Data([0x00, 0x00, 0x00, 0x02,      // count (position, object)
                           0, 0, 0, 0,                  // align
                           0x6B, 0x70, 0x6F, 0x73,      // * keyAEPosition
                           0x65, 0x6E, 0x75, 0x6D,      //   typeEnumerated
                           0x00, 0x00, 0x00, 0x04])     //   size (4 bytes)
        result += packUInt32(self.position.rawValue)    //   enum code
        result += Data([0x6B, 0x6F, 0x62, 0x6A])        // * keyAEObject
        self.from.appendTo(containerData: &result)      //   descriptor
        return result
    }
    
    public let position: Position
    public let from: Query
    
    // called by Unflatten.swift
    internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> InsertionLocation {
        // type, remaining bytes // TO DO: sanity check these?
        var position: OSType? = nil, from: Query? = nil
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
                let desc: Descriptor                                                    //   Query
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                // object specifier's parent is either an object specifier or its terminal [root] descriptor
                from = (desc.type == typeObjectSpecifier) ? (desc as! Query) : RootSpecifier(from: desc)
            default:
                throw AppleEventError.invalidParameter
            }
        }
        guard let position_ = position, let from_ = from, let position__ = Position(rawValue: position_) else {
                throw AppleEventError.invalidParameter
        }
        return InsertionLocation(position: position__, from: from_)
    }
}



public struct ComparisonDescriptor: Test {
    
    public enum Operator: OSType {
        case lessThan           = 0x3C202020 // kAELessThan
        case lessThanOrEqual    = 0x3C3D2020 // kAELessThanEquals
        case equal              = 0x3D202020 // kAEEquals
        case notEqual           = 0x00000001 // kAENotEquals // will pack as kAEEquals + kAENOT
        case greaterThan        = 0x3E202020 // kAEGreaterThan
        case greaterThanOrEqual = 0x3E3D2020 // kAEGreaterThanEquals
        case beginsWith         = 0x62677774 // kAEBeginsWith
        case endsWith           = 0x656E6473 // kAEEndsWith
        case contains           = 0x636F6E74 // kAEContains
        case isIn               = 0x00000002 // kAEIsIn // will pack as kAEContains with operands reversed
    }
    
    public let type: DescType = typeCompDescriptor

    public var data: Data { // caution: this returns an incomplete representation of .notEqual; see also appendTo(:)
        let lhs: Descriptor, op: Operator, rhs: Descriptor
        switch self.comparison {
        case .notEqual: (lhs, op, rhs) = (self.object, .equal, self.value)    // convert 'A != B' to 'NOT (A == B)'
        case .isIn:     (lhs, op, rhs) = (self.value, .contains, self.object) // convert 'A in B' to 'B contains A'
        default:        (lhs, op, rhs) = (self.object, self.comparison, self.value)
        }
        var result = Data([0x00, 0x00, 0x00, 0x03,  // count (object1, operator, object2)
                           0, 0, 0, 0,              // align
                           0x6F, 0x62, 0x6A, 0x31]) // * keyAEObject1
        lhs.appendTo(containerData: &result)        //   descriptor
        result += Data([0x72, 0x65, 0x6C, 0x6F,     // * keyAECompOperator
                        0x65, 0x6E, 0x75, 0x6D,     //   typeEnumerated
                        0x00, 0x00, 0x00, 0x04])    //   size (4 bytes)
        result += packUInt32(op.rawValue)           //   enum code
        result += Data([0x6F, 0x62, 0x6A, 0x32])    // * keyAEObject2
        rhs.appendTo(containerData: &result)        //   descriptor
        return result
    }
    
    public let object: Descriptor // this should always be Query
    public let comparison: Operator
    public let value: Descriptor // this may be a primitive value or another query
    
    public func appendTo(containerData result: inout Data) {
        // an 'is not equal to' test is constructed by wrapping a kAEEquals comparison descriptor in a kAENOT logical descriptor
        if self.comparison == .notEqual {
            result += Data([0x6C, 0x6F, 0x67, 0x69])            // typeLogicalDescriptor
            result += packUInt32(UInt32(self.data.count + 52))  // remaining bytes // TO DO: check this is correct
            result += Data([0x00, 0x00, 0x00, 0x02,             // count (operator, operands list)
                            0, 0, 0, 0,                         // align
                            0x6C, 0x6F, 0x67, 0x63,             // * keyAELogicalOperator
                            0x65, 0x6E, 0x75, 0x6D,             //   typeEnumerated
                            0x00, 0x00, 0x00, 0x04,             //   size (4 bytes)
                            0x4E, 0x4F, 0x54, 0x20,             //   kAENOT
                            0x74, 0x65, 0x72, 0x6D,             // * keyAELogicalTerms // a single-item list containing this comparison
                            0x6C, 0x69, 0x73, 0x74])            //   typeAEList
            result += packUInt32(UInt32(self.data.count + 16))  //   remaining bytes // TO DO: ditto
            result += Data([0x00, 0x00, 0x00, 0x01,             //   number of items
                            0, 0, 0, 0])                        //   align
        }
        // append this comparison descriptor
        result += packUInt32(self.type)                         // descriptor type
        result += packUInt32(UInt32(self.data.count))           // remaining bytes
        result += self.data                                     // descriptor data
    }
    
    // called by Unflatten.swift
    internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> ComparisonDescriptor {
        // type, remaining bytes // TO DO: sanity check these?
        var object: Descriptor? = nil, comparison: OSType? = nil, value: Descriptor? = nil
        let countOffset = descStart + 8
        if data.readUInt32(at: countOffset) != 3 { throw AppleEventError.invalidParameterCount }
        var offset = countOffset + 8
        for _ in 0..<3 {
            let key = data[offset..<(offset+4)]
            switch key {
            case Data([0x6F, 0x62, 0x6A, 0x31]):                                        // * keyAEObject1
                let desc: Descriptor                                                    //   Query
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                // object specifier's parent is either an object specifier or its terminal [root] descriptor
                object = desc
            case Data([0x72, 0x65, 0x6C, 0x6F])                                         // * keyAECompOperator
                where data[(offset+4)..<(offset+12)] == Data([0x65, 0x6E, 0x75, 0x6D,   //   typeEnumerated
                                                              0x00, 0x00, 0x00, 0x04]): //   size (4 bytes)
                comparison = data.readUInt32(at: offset+12)
                offset += 16
            case Data([0x6F, 0x62, 0x6A, 0x32]):                                        // * keyAEObject2
                let desc: Descriptor                                                    //   Query
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                // object specifier's parent is either an object specifier or its terminal [root] descriptor
                value = desc
            default:
                throw AppleEventError.invalidParameter
            }
        }
        guard var object_ = object, let comparison_ = comparison, var value_ = value,
            var comparison__ = Operator(rawValue: comparison_) else {
            throw AppleEventError.invalidParameter
        }
        if comparison__ == .contains && !(object_ is Query) {
            (object_, comparison__, value_) = (value_, .isIn, object_)
        }
        guard let object__ = object_ as? Query else { throw AppleEventError.invalidParameter }
        return ComparisonDescriptor(object: object__, comparison: comparison__, value: value_)
    }
    
}


public struct LogicalDescriptor: Test {
    
    public enum Operator: OSType {
        case AND    = 0x414E4420 // kAEAND
        case OR     = 0x4F522020 // kAEOR
        case NOT    = 0x4E4F5420 // kAENOT
    }

    public let type: DescType = typeLogicalDescriptor
    
    public var data: Data {
        var result = Data([0x00, 0x00, 0x00, 0x02,      // count
                           0, 0, 0, 0,                  // align
                           0x6C, 0x6F, 0x67, 0x63,      // * keyAELogicalOperator
                           0x65, 0x6E, 0x75, 0x6D,      //   typeEnumerated
                           0x00, 0x00, 0x00, 0x04])     //   size (4 bytes)
        result += packUInt32(self.logical.rawValue)     //   enum code
        result += Data([0x74, 0x65, 0x72, 0x6D])        // * keyAELogicalTerms
        self.operands.appendTo(containerData: &result)  //   descriptor
        return result
    }
    
    public let logical: Operator
    public let operands: ListDescriptor // must contain logical and/or comparison descriptors; initializers must ensure correct no of operands (>=2 for AND/OR; ==1 for NOT)
    
    private init(logical: Operator, operands: [Test]) { // used by AND/OR initializers below
        if operands.count < 2 { fatalError("Too few operands.") } // TO DO: how to deal with errors?
        self.logical = logical
        var result = Data()
        for op in operands { op.appendTo(containerData: &result) }
        self.operands = ListDescriptor(count: UInt32(operands.count), data: result)
    }
    
    // TO DO: use varargs for following? that'd prevent too few args being passed (first two args would be explicit)
    
    public init(AND operands: [Test]) {
        self.init(logical: .AND, operands: operands)
    }
    
    public init(OR operands: [Test]) {
        self.init(logical: .OR, operands: operands)
    }
    
    public init(NOT operand: Test) {
        self.logical = .NOT
        var result = Data()
        operand.appendTo(containerData: &result)
        self.operands = ListDescriptor(count: 1, data: result)
    }
    
    // called by Unflatten.swift
    internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> LogicalDescriptor {
        // type, remaining bytes // TO DO: sanity check these?
        var logical: OSType? = nil, operands: [Test]? = nil
        let countOffset = descStart + 8
        if data.readUInt32(at: countOffset) != 2 { throw AppleEventError.invalidParameterCount }
        var offset = countOffset + 8
        for _ in 0..<2 {
            let key = data[offset..<(offset+4)]
            switch key {
            case Data([0x6C, 0x6F, 0x67, 0x63])                                         // * keyAELogicalOperator
                where data[(offset+4)..<(offset+12)] == Data([0x65, 0x6E, 0x75, 0x6D,   //   typeEnumerated
                                                              0x00, 0x00, 0x00, 0x04]): //   size (4 bytes)
                logical = data.readUInt32(at: offset+12)
                offset += 16
            case Data([0x74, 0x65, 0x72, 0x6D]):                                        // * keyAELogicalTerms
                let desc: Descriptor                                                    //   Query
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                // object specifier's parent is either an object specifier or its terminal [root] descriptor
                if desc.type != typeAEList { throw AppleEventError.invalidParameter }
                operands = try unpackAsArray(desc, using: { (desc: Descriptor) throws -> Test in
                    // TO DO: this is kludgy; would be better not to use -ve start indexes (probably be simpler just to iterate flattened list directly)
                    switch desc.type {
                    case typeLogicalDescriptor:
                        return try LogicalDescriptor.unflatten(desc.data, startingAt: -8)
                    case typeCompDescriptor:
                        return try ComparisonDescriptor.unflatten(desc.data, startingAt: -8)
                    default:
                        throw AppleEventError.invalidParameter
                    }
                })
            default:
                throw AppleEventError.invalidParameter
            }
        }
        guard let logical_ = logical, let operands_ = operands, let logical__ = Operator(rawValue: logical_),
            ((logical__ == .NOT && operands_.count == 1) || operands_.count >= 2) else {
            throw AppleEventError.invalidParameter
        }
        return LogicalDescriptor(logical: logical__, operands: operands_)
    }

}


public extension Test {

    static func &&(lhs: Test, rhs: Test) -> Test {
        return LogicalDescriptor(AND: [lhs, rhs])
    }
    static func ||(lhs: Test, rhs: Test) -> Test {
        return LogicalDescriptor(OR: [lhs, rhs])
    }
    static prefix func !(lhs: Test) -> Test {
        return LogicalDescriptor(NOT: lhs)
    }
}
