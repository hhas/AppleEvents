//
//  main.swift
//

// unlike Apple Event Manager/NSAppleEventDescriptor, which include general list/record descriptor manipulation APIs, these APIs are solely concerned with converting data between Swift and AE types as quickly and safely as practical; descriptor records are always immutable, and do not provide random data access


// TO DO: how best to map to/from client-code-defined Swift structs and enums?

// TO DO: how to support default values? (in sylvia-lang, we distinguish between transient and permanent coercion errors; thus a 'missing value' coercion error that occurs on a list item can be intercepted by a 'use default item' function, but will not propagate beyond that point to inadvertently trigger a 'use default list' function)

import Foundation

// simplest way to test our descriptors is to flatten them, then pass to AEUnflattenDesc() and wrap as NSAppleEventDescriptor and see how they compare

@discardableResult func flattenNSDesc(_ desc: NSAppleEventDescriptor) -> Data {
    print("Flattening:", desc)
    var aeDesc = desc.aeDesc!.pointee
    let size = AESizeOfFlattenedDesc(&aeDesc)
    let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: size)
    let err = Int(AEFlattenDesc(&aeDesc, ptr, size, nil))
    if err != 0 { print("AEFlatten error \(err). \(descriptionForError[err] ?? "")") }
    let dat = Data(bytesNoCopy: ptr, count: size, deallocator: .none)
    dumpFourCharData(dat)
    return dat
}

@discardableResult func unflattenAsNSDesc(_ data: Data) -> NSAppleEventDescriptor? {
    var data = data
    var result = AEDesc(descriptorType: typeNull, dataHandle: nil)
    let err = data.withUnsafeMutableBytes { Int(AEUnflattenDesc($0, &result)) }
    if err != 0 {
        print("Unflatten error \(err). \(descriptionForError[err] ?? "")")
        return nil
    } else {
        let nsDesc = NSAppleEventDescriptor(aeDescNoCopy: &result)
        print(nsDesc)
        return nsDesc
    }
}
    

// pack/unpack functions are composable and reusable:
let unpackAsArrayOfInt = newUnpackArrayFunc(using: unpackAsInt)
let unpackAsArrayOfString = newUnpackArrayFunc(using: unpackAsString)

/*
do {
    let desc = packAsString("Hello, World!")
    print(desc)
    print(try unpackAsString(desc)) // "Hello, World!"
    print(try unpackAsArrayOfString(desc)) // ["Hello, World!"]
}




do {
    let desc = packAsString("32")
    print(try unpackAsArrayOfInt(desc)) // [32]
}


do {
    let desc = packAsArray([32, 4], using: packAsInt)
    
    dumpFourCharData(desc.flatten())
    
    print(try unpackAsArrayOfString(desc)) // ["32", "4"]
}
*/

do {
    
    let query = applicationRoot.elements(cDocument).byIndex(packAsInt(1)).property(pName)
    print(query)

    let d = query.flatten()
    //dumpFourCharData(d)
    
    unflattenAsNSDesc(d)
    
}
