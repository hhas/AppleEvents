//
//  main.swift
//  test-handler
//

import CoreFoundation
//import Foundation
import AppleEvents



// TO DO: higher-level API should provide human-readable error messages (so needs to know parameter names and be able to describe required type[s]); ideally all params should be processed before generating complete error description as multiple params may be invalid (one problem with this is that standard kOSAExpectedType/kOSAErrorOffendingObject error keys can only describe a single issue, and kOSAExpectedType cannot describe complex types; may be worth defining new keys for extended error info)

// TO DO: IDL should include human-readable descriptions of any custom error codes defined by server (error domain = bundle identifier); these may be simple strings or templates (fields would be param keys, allowing client to unpack reply event parameters and format them natively before inserting into template)

appleEventHandlers[eventOpenDocuments] = { (event: AppleEventDescriptor) throws -> Descriptor? in
    guard let desc = event.parameter(keyDirectObject) else { throw AppleEventError.missingParameter }
    print("open", try unpackAsArray(desc, using: unpackAsFileURL))
    return RootSpecifierDescriptor.app.elements(cDocument).byIndex(packAsInt32(1)) // return [list of] specifier identifying opened document[s]
}

appleEventHandlers[coreEventGetData] = { (event: AppleEventDescriptor) throws -> Descriptor? in
    guard let desc = event.parameter(keyDirectObject) else { throw AppleEventError.missingParameter }
    print("get", desc)
    return packAsString("Hello")
}

appleEventHandlers[coreEventClose] = { (event: AppleEventDescriptor) throws -> Descriptor? in
    guard let desc = event.parameter(keyDirectObject) else { throw AppleEventError.missingParameter }
    // TO DO: optional `saving` parameter
    print("close", desc)
    return nil
}

appleEventHandlers[eventQuitApplication] = { (event: AppleEventDescriptor) throws -> Descriptor? in
    print("quit")
    CFRunLoopStop(CFRunLoopGetCurrent())
    return nil
}




print("pid = \(getpid())")



// TO DO: registered Mach port also receives non-AE messages; how should these be handled? (e.g. when running test script, the received AEs are preceded by a non-AE message which AEDecodeMessage rejects with error -50)
let source = CFMachPortCreateRunLoopSource(nil, AppleEvents.createMachPort(), 1)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CFRunLoopRun()

