//
//  Unflatten.swift
//

import Foundation

// caution: this does not perform bounds/sanity checks for malformed/truncated data

// TO DO: problem: how to tell if an AERecord with non-reco type is a record or a scalar? AEIsRecord() seems to know; does it pattern match data structure, or is there some hidden flag?



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


private let dle2Offsets = Offsets(type: 8, count: 32)
private let defaultOffsets = Offsets(type: 0, count: 8)


// TO DO: pass startOffset here, avoiding extra slicing
private func unflatten(data: Data, offsets: Offsets) -> (descriptor: Descriptor, endOffset: Int) {
    let type = data.readUInt32(at: offsets.type) // type
    let remainingBytesOffset = offsets.type + 4
    // data section's start index varies according to descriptor type
    let dataEnd = Int(data.readUInt32(at: remainingBytesOffset)) + remainingBytesOffset + 4 // remaining bytes
    let result: Descriptor
    switch type {
    case typeAEList:
        // [format, align,] type, bytes, [16-byte reserved,] count, align, DATA
        let dataStart = offsets.count + 8
        result = ListDescriptor(count: data.readUInt32(at: 32), data: data[dataStart..<dataEnd])
    case typeAERecord:
        // [format, align,] type, bytes, [16-byte reserved,] count, align, DATA
        let dataStart = offsets.count + 8
        result = RecordDescriptor(type: type, count: data.readUInt32(at: 32), data: data[dataStart..<dataEnd])
    case typeAppleEvent:
        // TO DO
        result = AppleEventDescriptor.unflatten(data)
    case typeProcessSerialNumber, typeKernelProcessID, typeApplicationBundleID, typeApplicationURL:
        // [format, align,] type, size, DATA
        let dataStart = offsets.type + 8
        result = ScalarDescriptor(type: type, data: data[dataStart..<dataEnd])
    default: // scalar
        // TO DO: how to reimplement AEIsRecord()? right now, any flattened record with non-reco type is structurally indistinguishable from scalar
        // [format, align,] type, size, DATA
        let dataStart = offsets.type + 8
        result = ScalarDescriptor(type: type, data: data[dataStart..<dataEnd])
    }
    return (result, dataEnd)
}


public func unflattenDescriptor(_ data: Data) -> Descriptor { // analogous to AEUnflattenDesc()
    if data[0..<4] != formatMarker {
        fatalError("'dle2' mark not found.") // TO DO: how to deal with malformed data? (check what AEUnflattenDesc does; if it accepts either then switch offsets)
    }
    let (result, endOffset) = unflatten(data: data, offsets: dle2Offsets)
    if endOffset != data.count { fatalError("Bad data length.") } // TO DO: ditto
    return result
}


// used by list/record/etc to unpack items

internal func unflattenFirstDescriptor(in data: Data, startingAt startOffset: Int = 0) -> (descriptor: Descriptor, endOffset: Int) {
    if data[startOffset..<(startOffset+4)] == formatMarker {
        fatalError("Unexpected 'dle2' mark found (expected descriptor type instead).")
    }
    return unflatten(data: data, offsets: defaultOffsets.add(startOffset))
}

