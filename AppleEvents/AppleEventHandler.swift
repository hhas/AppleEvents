//
//  EventHandler.swift
//

import Foundation

// TO DO: the registered Mach port receives both AE and non-AE messages; what should we do with the latter? would help to know what the non-AE message does - it precedes the first AE sent by a client, implying some sort of preparation (e.g. getting server’s AE entitlements info, as defined in its SDEF?)

// TO DO: what about AppKit-based processes? installing our own Mach port source may conflict with AppKit's standard AE hooks, in which case we should install a wildcard handler via Carbon/NSAppleEventManager that forwards unhandled AEs to our own dispatcher, although that smells kludgy and inefficient)

// TO DO: how should next layer above AppleEventHandler look? presumably we need some sort of app-specific glue to map Swift functions with native parameter and return types onto AppleEventHandler callbacks; should Swift functions use standardized naming conventions, allowing them to be auto-detected by glue generator and signatures mapped to 'SDEF' definitions (note: we want to architect a new, comprehensive IDL dictionary format, with basic SDEFs generated for backwards compatibility; the IDL should, as much as possible, be auto-generated from the Swift implementation)


// TO DO: what about completion callbacks for async use? (analogous to suspend/resume current event) Q. what are [dis]advantages of using completion callbacks as standard? (avoids blocking [main] thread; may be slightly more expensive, cannot guarantee callback will ever be called [although clients will typically specify timeout to avoid waiting forever])

// TO DO: may want to define AE handler as struct; that'll allow runtime introspection (the entire interface should be explorable, with any static definitions being generated from that) (if it weren't for AS's dependency on four-char code stability, we could also generate four-char codes on the fly; as it is, we will have to generate new four-char codes as delta to existing ones); another reason to use structs + protocol is that it makes it easy to support multimethods

// Q. to what extent should we use pattern-based dispatching? (e.g. we might dispatch on topmost descriptor of target query, or on topmost descriptor's parent - e.g. in `count`; we might want to walk descriptor chain from application root, with ability to register functions at any point in that graph; safe vs mutating commands will want to use different behaviors; operations on concrete vs abstract nodes - e.g. window vs word - will definitely want to process differently; and so on; subject [target] vs object [receiver] specifiers); definitely something to be said for OSL's mix-n-match approach, though ideally we want to abstract away most if not all of that boilerplate behind a declarative IDL/DSL


private func handleEvent(port: CFMachPort?, message: UnsafeMutableRawPointer?, size: CFIndex, info: UnsafeMutableRawPointer?) {
    // TO DO: reverse-engineer AE-over-Mach serialization format (it's not the same format as AEFlattenDesc!) and eliminate carbonReceive() kludge
    let header = message!.bindMemory(to: UInt32.self, capacity: 6)
    /*
         public var msgh_bits: mach_msg_bits_t
         public var msgh_size: mach_msg_size_t
         public var msgh_remote_port: mach_port_t
         public var msgh_local_port: mach_port_t
         public var msgh_voucher_port: mach_port_name_t
         public var msgh_id: mach_msg_id_t
     */
    print("handleEvent msgh_bits: \(String(format: "%08x", header[0])) msgh_size: \(header[1])")
    // carbonReceive will return (paramErr=-50) if not an AE; what other codes?
    let err = carbonReceive(message: message!.bindMemory(to: mach_msg_header_t.self, capacity: 1)) {
        // errors raised here are automatically packed into reply event
        try (appleEventHandlers[$0.code] ?? defaultEventHandler)($0)
    }
    if err != 0 { print("handleEvent error: \(err)") } // TO DO: delegate for non-AE messages?
}


// public API (this is NOT final design)

public typealias AppleEventHandler = (AppleEventDescriptor) throws -> Descriptor?


// installed handlers
public var appleEventHandlers = [EventIdentifier: AppleEventHandler]() // this might eventually become private if we decide to mediate access (e.g. multimethods require additional logic as each handler is additive, e.g. `get document` and `get window` would both occupy same slot, regardless of whether they share a common implementation or each defines its own); also, we probably want to prevent "********" being registered here, as wildcard handler is defined separately below; Q. should we disallow installing over existing handlers? how can we safely support 'scriptable plugins' (also bear in mind that most plugins will operate as XPC subprocesses, rather than inject into main process)


// wildcard handler
public var defaultEventHandler: AppleEventHandler = { _ in throw AppleEventError.unsupportedAppleEvent }


public func createMachPort() -> CFMachPort {
    return CFMachPortCreateWithPort(nil, carbonPort(), handleEvent, nil, nil)
}

