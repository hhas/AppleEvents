//
//  Unflatten.swift
//

import Foundation

// TO DO: Mach messages use different layout to AEFlattenDesc

// caution: this does not perform bounds/sanity checks for malformed/truncated data


private let formatMarker = Data([0x64, 0x6c, 0x65, 0x32]) // 'dle2'


private struct Offsets {
    // typeOffset = 8/0
    // remainingBytesOffset = typeOffset+4
    // countOffset (reco/list) = 32/8 (additional padding inbetween)
    // dataStartOffset (scalar) = typeOffset+8
    // dataStartOffset (reco/list) = countOffset+8
    
    let type: Int
    let count: Int
    // TO DO: offsets for typeAppleEvent descriptor
    
    func add(_ offset: Int) -> Offsets {
        return Offsets(type: self.type + offset, count: self.count + offset)
    }
}


// offsets of descriptorType and [in AEList/AERecord only] numberOfItems fields
private let dle2Offsets = Offsets(type: 8, count: 32)
private let defaultOffsets = Offsets(type: 0, count: 8)


// used by unflattenDescriptor(), unflattenFirstDescriptor() below
// CAUTION: offsets are absolute to underlying data buffer // TO DO: how best to manage this? safest would be to wrap data in our own DataReader struct that mediates all access, adjusting offsets relative to underlying data buffer; or should we copy Data prior to instantiating new Descriptor (right now descriptors will hang onto shared underlying buffer)
private func unflatten(data: Data, offsets: Offsets) throws -> (descriptor: Descriptor, endOffset: Int) {
    // TO DO: Descriptor.unflatten() calls should probably return end offset for sanity checking
    let type = data.readUInt32(at: offsets.type) // type
    let remainingBytesOffset = offsets.type + 4
    // data section's start index varies according to descriptor type
    let dataEnd = Int(data.readUInt32(at: remainingBytesOffset)) + remainingBytesOffset + 4 // remaining bytes
    let result: Descriptor
    switch type { // fields in brackets are only included in top-level structures flattened as dle2
    case typeAEList:
        // [format='dle2', align,] type='list', bytes, [16-byte reserved,] count, align, DATA
        result = ListDescriptor(count: data.readUInt32(at: offsets.count), data: data[(offsets.count + 8)..<dataEnd])
    case typeAERecord:
        // [format='dle2', align,] type='reco', bytes, [16-byte reserved,] count, align, DATA
        result = RecordDescriptor(type: type, count: data.readUInt32(at: offsets.count), data: data[(offsets.count + 8)..<dataEnd])
    case typeObjectSpecifier:
        // [format='dle2', align,] type='obj ', bytes, count=4, align, DATA
        result = try ObjectSpecifierDescriptor.unflatten(data, startingAt: offsets.type)
    case typeInsertionLoc:
        result = try InsertionLocationDescriptor.unflatten(data, startingAt: offsets.type)
    case typeRangeDescriptor:
        result = try ObjectSpecifierDescriptor.RangeDescriptor.unflatten(data, startingAt: offsets.type)
    case typeCompDescriptor:
        result = try ComparisonDescriptor.unflatten(data, startingAt: offsets.type)
    case typeLogicalDescriptor:
        result = try LogicalDescriptor.unflatten(data, startingAt: offsets.type)
    case typeAppleEvent:
        // TO DO: AppleEventDescriptor.unflatten() currently expects full AE descriptor including dle2 header, and doesn't accept non-zero start index; need to check how nested AEs are laid out
        result = try AppleEventDescriptor.unflatten(data, startingAt: 0)
    case typeProcessSerialNumber, typeKernelProcessID, typeApplicationBundleID, typeApplicationURL:
        // [format (dle2), align,] type, size, DATA
        result = ScalarDescriptor(type: type, data: data[(offsets.type + 8)..<dataEnd])
    default: // scalar
        // TO DO: how to reimplement AEIsRecord()? right now, any flattened record with non-reco type is structurally indistinguishable from scalar
        // [format, align,] type, size, DATA
        result = ScalarDescriptor(type: type, data: data[(offsets.type + 8)..<dataEnd])
    }
    return (result, dataEnd % 2 == 0 ? dataEnd : dataEnd + 1)
}


public func unflattenDescriptor(_ data: Data) -> Descriptor { // analogous to AEUnflattenDesc()
    if data[data.startIndex..<(data.startIndex + 4)] != formatMarker {
        fatalError("'dle2' mark not found.") // TO DO: how to deal with malformed data? (check what AEUnflattenDesc does; if it accepts either then switch offsets)
    }
    let (result, endOffset) = try! unflatten(data: data, offsets: dle2Offsets)
    if endOffset != data.count { fatalError("Bad data length.") } // TO DO: ditto
    return result
}


// used by list/record/etc to unpack items

// TO DO: ensure startOffset is always original Data[Slice]'s index

internal func unflattenFirstDescriptor(in data: Data, startingAt startOffset: Int) -> (descriptor: Descriptor, endOffset: Int) {
    //print(">>>",startOffset, "in", data.startIndex, data.endIndex)
    if data[startOffset..<(startOffset + 4)] == formatMarker {
        fatalError("Unexpected 'dle2' mark found (expected descriptor type instead).")
    }
    return try! unflatten(data: data, offsets: defaultOffsets.add(startOffset))
}

