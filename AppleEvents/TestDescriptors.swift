//
//  TestDescriptors.swift
//

import Foundation



public struct ComparisonDescriptor: TestDescriptor {
    
    public var debugDescription: String {
        return "<\(Swift.type(of: self)) \(self.object) \(self.comparison) \(self.value)>"
    }
    
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
        result += encodeUInt32(op.rawValue)           //   enum code
        result += Data([0x6F, 0x62, 0x6A, 0x32])    // * keyAEObject2
        rhs.appendTo(containerData: &result)        //   descriptor
        return result
    }
    
    public let object: QueryDescriptor // either RootSpecifierDescriptor.its (e.g. `words where it begins with "a"`) or InsertionLocationDescriptor (TO DO: SpecifierProtocol?)
    public let comparison: Operator
    public let value: Descriptor // this may be a primitive value or another query
    
    // TO DO: TEMPORARY; SwiftAutomation currently creates directly
    public init(object: QueryDescriptor, comparison: Operator, value: Descriptor) {
        self.object = object
        self.comparison = comparison
        self.value = value
    }
    
    public func appendTo(containerData result: inout Data) {
        // an 'is not equal to' test is constructed by wrapping a kAEEquals comparison descriptor in a kAENOT logical descriptor
        if self.comparison == .notEqual {
            result += Data([0x6C, 0x6F, 0x67, 0x69])            // typeLogicalDescriptor
            result += encodeUInt32(UInt32(self.data.count + 52))  // remaining bytes // TO DO: check this is correct
            result += Data([0x00, 0x00, 0x00, 0x02,             // count (operator, operands list)
                0, 0, 0, 0,                         // align
                0x6C, 0x6F, 0x67, 0x63,             // * keyAELogicalOperator
                0x65, 0x6E, 0x75, 0x6D,             //   typeEnumerated
                0x00, 0x00, 0x00, 0x04,             //   size (4 bytes)
                0x4E, 0x4F, 0x54, 0x20,             //   kAENOT
                0x74, 0x65, 0x72, 0x6D,             // * keyAELogicalTerms // a single-item list containing this comparison
                0x6C, 0x69, 0x73, 0x74])            //   typeAEList
            result += encodeUInt32(UInt32(self.data.count + 16))  //   remaining bytes // TO DO: ditto
            result += Data([0x00, 0x00, 0x00, 0x01,             //   number of items
                0, 0, 0, 0])                        //   align
        }
        // append this comparison descriptor
        result += encodeUInt32(self.type)                         // descriptor type
        result += encodeUInt32(UInt32(self.data.count))           // remaining bytes
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
                let desc: Descriptor                                                    //   QueryDescriptor/Descriptor
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                // object specifier's parent is either an object specifier or its terminal [root] descriptor
                object = desc
            case Data([0x72, 0x65, 0x6C, 0x6F])                                         // * keyAECompOperator
                where data[(offset+4)..<(offset+12)] == Data([0x65, 0x6E, 0x75, 0x6D,   //   typeEnumerated
                    0x00, 0x00, 0x00, 0x04]): //   size (4 bytes)
                comparison = data.readUInt32(at: offset+12)
                offset += 16
            case Data([0x6F, 0x62, 0x6A, 0x32]):                                        // * keyAEObject2
                let desc: Descriptor                                                    //   QueryDescriptor/Descriptor
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
        if comparison__ == .contains && !(object_ is QueryDescriptor) {
            (object_, comparison__, value_) = (value_, .isIn, object_)
        }
        guard let object__ = object_ as? QueryDescriptor else { throw AppleEventError.invalidParameter }
        return ComparisonDescriptor(object: object__, comparison: comparison__, value: value_)
    }
    
}


// logical tests, e.g. `not TEST`, `TEST1 or TEST2`, `and(TEST1,TEST2,TEST3,…)`

public struct LogicalDescriptor: TestDescriptor {
    
    public var debugDescription: String {
        return "<\(Swift.type(of: self)) \(self.logical) \(self.operands)>"
    }
    
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
        result += encodeUInt32(self.logical.rawValue)     //   enum code
        result += Data([0x74, 0x65, 0x72, 0x6D])        // * keyAELogicalTerms
        self.operands.appendTo(containerData: &result)  //   descriptor
        return result
    }
    
    public let logical: Operator
    public let operands: ListDescriptor // must contain logical and/or comparison descriptors; initializers must ensure correct no of operands (>=2 for AND/OR; ==1 for NOT)
    
    // TO DO: TEMPORARY; SwiftAutomation currently creates directly
    public init(logical: Operator, operands: ListDescriptor) {
        self.logical = logical
        self.operands = operands
    }
    
    private init(logical: Operator, operands: [TestDescriptor]) { // used by AND/OR initializers below
        if operands.count < (logical == .NOT ? 1 : 2) { fatalError("Too few operands.") } // TO DO: how to deal with errors?
        self.logical = logical
        var result = Data()
        for op in operands { op.appendTo(containerData: &result) }
        self.operands = ListDescriptor(count: UInt32(operands.count), data: result)
    }
    
    // TO DO: use varargs for following? that'd prevent too few args being passed (first two args would be explicit)
    
    public init(AND operands: [TestDescriptor]) {
        self.init(logical: .AND, operands: operands)
    }
    
    public init(OR operands: [TestDescriptor]) {
        self.init(logical: .OR, operands: operands)
    }
    
    public init(NOT operand: TestDescriptor) {
        self.logical = .NOT
        var result = Data()
        operand.appendTo(containerData: &result)
        self.operands = ListDescriptor(count: 1, data: result)
    }
    
    // called by Unflatten.swift
    internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> LogicalDescriptor {
        // type, remaining bytes // TO DO: sanity check these?
        var logical: OSType? = nil, operands: [TestDescriptor]? = nil
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
                let desc: Descriptor                                                    //   QueryDescriptor
                (desc, offset) = unflattenFirstDescriptor(in: data, startingAt: offset+4)
                // object specifier's parent is either an object specifier or its terminal [root] descriptor
                if desc.type != typeAEList { throw AppleEventError.invalidParameter }
                operands = try unpackAsArray(desc, using: { (desc: Descriptor) throws -> TestDescriptor in
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


public extension TestDescriptor {
    
    static func &&(lhs: TestDescriptor, rhs: TestDescriptor) -> TestDescriptor {
        return LogicalDescriptor(AND: [lhs, rhs])
    }
    static func ||(lhs: TestDescriptor, rhs: TestDescriptor) -> TestDescriptor {
        return LogicalDescriptor(OR: [lhs, rhs])
    }
    static prefix func !(lhs: TestDescriptor) -> TestDescriptor {
        return LogicalDescriptor(NOT: lhs)
    }
}
