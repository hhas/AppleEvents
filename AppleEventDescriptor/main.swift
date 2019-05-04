//
//  main.swift
//

// unlike Apple Event Manager/NSAppleEventDescriptor, which include general list/record descriptor manipulation APIs, these APIs are solely concerned with converting data between Swift and AE types as quickly and safely as practical; descriptor records are always immutable, and do not provide random data access


// TO DO: how best to map to/from client-code-defined Swift structs and enums?

// TO DO: how to support default values? (in sylvia-lang, we distinguish between transient and permanent coercion errors; thus a 'missing value' coercion error that occurs on a list item can be intercepted by a 'use default item' function, but will not propagate beyond that point to inadvertently trigger a 'use default list' function)

import Foundation


// pack/unpack functions are composable and reusable:
let unpackAsArrayOfInt = newUnpackArrayFunc(using: unpackAsInt)
let unpackAsArrayOfString = newUnpackArrayFunc(using: unpackAsString)


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
