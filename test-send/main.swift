//
//  main.swift
//

// unlike Apple Event Manager/NSAppleEventDescriptor, which include general list/record descriptor manipulation APIs, these APIs are solely concerned with converting data between Swift and AE types as quickly and safely as practical; descriptor records are always immutable, and do not provide random data access


// TO DO: how best to map to/from client-code-defined Swift structs and enums?

// TO DO: how to support default values? (in sylvia-lang, we distinguish between transient and permanent coercion errors; thus a 'missing value' coercion error that occurs on a list item can be intercepted by a 'use default item' function, but will not propagate beyond that point to inadvertently trigger a 'use default list' function)

import Foundation
import AppleEvents

// simplest way to test our descriptors is to flatten them, then pass to AEUnflattenDesc() and wrap as NSAppleEventDescriptor and see how they compare


@discardableResult func flattenNSDesc(_ desc: NSAppleEventDescriptor) -> Data {
    print("Flattening:", desc)
    var aeDesc = desc.aeDesc!.pointee
    let size = AESizeOfFlattenedDesc(&aeDesc)
    let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: size)
    let err = Int(AEFlattenDesc(&aeDesc, ptr, size, nil))
    if err != 0 { print("AEFlatten error \(err).") }
    let dat = Data(bytesNoCopy: ptr, count: size, deallocator: .none)
    dumpFourCharData(dat)
    return dat
}

@discardableResult func unflattenAsNSDesc(_ data: Data) -> NSAppleEventDescriptor? {
    var data = data
    var result = AEDesc(descriptorType: typeNull, dataHandle: nil)
    let err = data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> Int in
        return Int(AEUnflattenDesc(ptr.baseAddress, &result))
    }
    if err != 0 {
        print("Unflatten error \(err).")
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
/*
do {
    
    let query = RootSpecifierDescriptor.app.elements(cDocument).byIndex(packAsInt(1)).property(pName)
    print(query)

    let d = query.flatten()
    //dumpFourCharData(d)
    
    unflattenAsNSDesc(d)
    
}
*/
/*
do {
    //let query = RootSpecifierDescriptor.app.elements(cDocument).byIndex(packAsInt(1)).property(pName)

    let query = NSAppleEventDescriptor.record().coerce(toDescriptorType: typeInsertionLocation)!
    query.setParam(NSAppleEventDescriptor(typeCode: cProperty), forKeyword: keyAEDesiredClass)
    query.setParam(NSAppleEventDescriptor(enumCode: formPropertyID), forKeyword: keyAEKeyForm)
    query.setParam(NSAppleEventDescriptor(typeCode: 0x686f6d65), forKeyword: keyAEKeyData) // 'home'
    query.setParam(NSAppleEventDescriptor.null(), forKeyword: keyAEContainer)
    
    let ae = NSAppleEventDescriptor(eventClass: kAECoreSuite, eventID: kAEGetData, targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder"), returnID: -1, transactionID: 0)
    
    ae.setParam(query, forKeyword: keyDirectObject)
    do {
        let result = try ae.sendEvent(options: [], timeout: 10)
        print(result)
    } catch {
        print(error)
    }
    print(ae)
    flattenNSDesc(ae)
}
*/




do {
    // note: app must already be running
    var ae = AppleEventDescriptor(code: coreEventGetData,
                                  target: try AddressDescriptor(bundleIdentifier: "com.apple.textedit"))
    
    let query = RootSpecifierDescriptor.app.elements(cDocument)
    ae.setParameter(keyDirectObject, to: query)
    let (code, reply) = ae.send()
    if code != 0 {
        print("AE error: \(code)")
    } else if let desc = reply?.parameter(keyErrorNumber) {
        print("App error: \(try unpackAsInt(desc))")
    } else if let result = reply?.parameter(keyAEResult) {
        dumpFourCharData(result.flatten())
    } else {
        print("<no-reply>")
    }
    
} catch {
    print("Apple event failed:", error)
}

