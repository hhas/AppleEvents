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
    let err = data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> Int in
        return Int(AEUnflattenDesc(ptr.baseAddress, &result))
    }
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
/*
do {
    
    let query = RootSpecifier.app.elements(cDocument).byIndex(packAsInt(1)).property(pName)
    print(query)

    let d = query.flatten()
    //dumpFourCharData(d)
    
    unflattenAsNSDesc(d)
    
}
*/
/*
do {
    //let query = RootSpecifier.app.elements(cDocument).byIndex(packAsInt(1)).property(pName)

    let query = NSAppleEventDescriptor.record().coerce(toDescriptorType: typeObjectSpecifier)!
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


// temporary kludge; allows us to send our homegrown AEs via established Carbon AESendMessage() API; aside from confirming that our code is reading and writing AEDesc data correctly (if not quirk-for-quirk compatible with AppleScript, then at least good enough to be understood by well-behaved apps), it gives us a benchmark to compare against as we implement our own Mach-AE bridging layer
func sendEvent(_ event: AppleEventDescriptor) throws -> ReplyEventDescriptor? {
    var data = event.flatten()
    var reply = AEDesc(descriptorType: typeNull, dataHandle: nil)
    let err = data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> Int in
        var event = AEDesc(descriptorType: typeNull, dataHandle: nil)
        let err = Int(AEUnflattenDesc(ptr.baseAddress, &event))
        if err != 0 {
            print("Unflatten error \(err). \(descriptionForError[err] ?? "")")
            return err
        }
        return Int(AESendMessage(&event, &reply, 0x73, 10 * 60)) // use 10 sec timeout for now
    }
    if err != 0 { throw AppleEventError(code: err, message: descriptionForError[err]) }
    let size = AESizeOfFlattenedDesc(&reply)
    let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: size)
    let err2 = Int(AEFlattenDesc(&reply, ptr, size, nil))
    if err2 != 0 { throw AppleEventError(code: err, message: "AEFlatten failed. \(descriptionForError[err] ?? "")") }
    let data2 = Data(bytesNoCopy: ptr, count: size, deallocator: .none)
    //dumpFourCharData(data2)
    if reply.descriptorType == typeNull { return nil } // TO DO: if kAENoReply is used then null descriptor is returned
    return try ReplyEventDescriptor.unflatten(data2, startingAt:0)
}



do {
    var ae = AppleEventDescriptor(code: (UInt64(kAECoreSuite) << 32) + UInt64(kAEGetData),
                                  target: try AddressDescriptor(bundleIdentifier: "com.apple.finder"))
    
    let query = RootSpecifier.app.property(0x686f6d65) // 'home'
    ae.setParameter(keyDirectObject, to: query)
    if let reply = try sendEvent(ae) {
        print(reply, (reply.parameter(keyErrorNumber) ?? "<no-error>"), (reply.parameter(keyAEResult) ?? "<no-result>"))
        if let result = reply.parameter(keyAEResult) {
            dumpFourCharData(result.flatten()) // messy output, as string values aren't guaranteed to be 4-bytes, but there should be enough readable lines to confirm it's an object specifier of form `folder "NAME" of folder "Users" of startup disk`
        }
    } else {
        print("<no-reply>")
    }
    
} catch {
    print("Apple event failed:", error)
}

