//
//  AppleEventDescriptor.swift
//

// Q. how might a modern UIKit app implement recording? (best way to record is for GUI to communicate with Model via AEs, as that ensures accurate representation of actions [it also in theory would allow an app's Model to run as independent headless server process to which any number of client UI processes may subscribe]; however, AppKit/UIKit aren't built to work that way, in which case they best they could do is emit recordable AEs as a side-effect to user interactions, which doesn't guarantee such AEs will be comprehensive or correct [since the App itself if not being made to eat its own dogfood, so is under no obligation to make sure those AEs are correct or that it has the AE handlers/AEOM capabilities to handle them], but may be "good enough" nevertheless in that even limited recordability will be helpful to users, both in its own right and as a learning tools for AE client languages)


// TO DO: should AppleEventDescriptor.send() automatically consolidate AE and App error codes, avoiding need for double checks? or should that be left to layer above?


/*
 
 TO DO: how to support following SendOptions?
 
 // ignore these for now (can revisit if/when we have an AEOM framework that supports recording)
 public static let dontRecord             = SendOptions(rawValue: 0x00001000) /* don't record this event */
 public static let dontExecute            = SendOptions(rawValue: 0x00002000) /* don't send the event for recording */
 
 // when is this needed? (and what does AESendMessage do with it?)
 public static let processNonReplyEvents  = SendOptions(rawValue: 0x00008000) /* allow processing of non-reply events while awaiting synchronous AppleEvent reply */
 
 // ditto
 public static let dontAnnotate           = SendOptions(rawValue: 0x00010000) /* if set, don't automatically add any sandbox or other annotations to the event */
 */




/*
 *  "dle2"     // format marker
 *  0x00000000 // align
 *  "aevt"     // type
 *  0x00000184 // bytes remaining
 *  0x00000000
 *  0x00000000
 *  0x00000134 // offset to parameters
 *  0x00000004
 *  0x00000001 // parameter count
 *  0x00000000
 *  0x00000000
 *  0x00000000
 *  "core"
 *  "getd"
 *  0x666f 0xbbb3 // unused, return ID
 *  […unused…]
 *  "aevt"
 *  0x00010001    // version marker
 *  [ATTRIBUTES]
 *  "tran"      * keyTransactionIDAttr
 *  "long"
 *  0x00000004
 *  0x00000000
 *  "addr"      * keyAddressAttr
 *  "bund"
 *  0x00000010
 *  "com.apple.finder"
 *  "tbsc"      * ??
 *  "psn "
 *  0x00000008
 *  0x00000000
 *  0x00000000
 *  "inte"      * keyInteractLevelAttr (this is set to 0 by AECreate; AESend will update it with SendOptions flags)
 *  "long"
 *  0x00000004
 *  0x00000070    [= alwaysInteract + canSwitchLayer]
 *  "repq"      * keyReplyRequestedAttr (again, this is set during AECreate, but AESend must replace it)
 *  "long"
 *  0x00000004
 *  0x00000000    // set to 1 by AESendMessage() if wait/queue reply flag is given
 *  "tbsc"      * ?? (duplicate field!)
 *  "psn "
 *  0x00000008
 *  0x00000000
 *  0x00000000
 *  "remo"      * ?? ('remote'?)
 *  "long"
 *  0x00000004
 *  0x00000000
 *  "from"      * keyOriginalAddressAttr
 *  "psn "
 *  0x00000008
 *  0x00000001
 *  0x000032a6
 *  "frec"      * ?? ('recording'?)
 *  "long"
 *  0x00000004
 *  0x00000000
 *  ";;;;"
 *  [PARAMETERS]
 *  "----"
 *  "obj "
 *  0x00000044
 *  0x00000004
 *  0x00000000
 *  "want"
 *  "type"
 *  0x00000004
 *  "docu"
 *  "form"
 *  "enum"
 *  0x00000004
 *  "indx"
 *  "seld"
 *  "long"
 *  0x00000004
 *  0x00000001
 *  "from"
 *  "null"
 *  0x00000000
 */


// TO DO: API for this is TBC (attributes in particular)

import Foundation


public typealias ReplyEventDescriptor = AppleEventDescriptor // TO DO: define a dedicated struct for representing reply events (typeAppleEvent with event identifier 'aevtansr')


public typealias AEReturnID = Int16
public typealias AETransactionID = Int32
public typealias AEEventClass = OSType
public typealias AEEventID = OSType


let kAutoGenerateReturnID: AEReturnID = -1 // TO DO: any reason this should be exposed to client code? inclined to hide it; only likely use-case is async messaging, where app's needs to know return IDs in order to match reply events when they arrive; however, this'd be best implemented as a modern Swift async API that takes a completion callback, in which case kAEWaitForReply and AEReturnID can be hidden behind that

let kAnyTransactionID: AETransactionID = 0 // TO DO: similarly, transactions would be best implemented as `withTransaction{…}` block, ensuring correct start/stop/cancel behaviors and avoiding client code having to handle transaction IDs itself; low-priority as few/no apps currently use them


private var returnIDCount: AEReturnID = AEReturnID.min // TO DO: auto-increment? or use sparse list? (what are chances of not receiving the reply to an outgoing event until 65536 outgoing events later?); caution: -1 is reserved (what about 0? -ve values? anything else?)

private func newReturnID() -> AEReturnID {
    returnIDCount += 1
    switch returnIDCount {
    case -1:
        returnIDCount = 1
    case AEReturnID.max:
        returnIDCount = AEReturnID.min
    default:
        ()
    }
    return returnIDCount
}




public struct AppleEventDescriptor: Descriptor {
    
    public enum InteractionLevel: UInt8 {
        case neverInteract  = 0x10 // server should not interact with user
        case canInteract    = 0x20 // server may try to interact with user
        case alwaysInteract = 0x30 // server should always interact with user where appropriate
    }
    
    public typealias Attribute = (key: AEKeyword, value: Descriptor)
    public typealias Parameter = (key: AEKeyword, value: Descriptor)
    
    public var debugDescription: String {
        return "<AppleEventDescriptor \(literalEightCharCode(self.code))>"
    }
    
    public let code: EventIdentifier
    public var target: AddressDescriptor? // pack as keyAddressAttr
    let returnID: AEReturnID
    
    
    public init(code: EventIdentifier, target: AddressDescriptor? = nil) { // create a new outgoing event
        self.code = code
        self.target = target
        self.returnID = newReturnID() // TO DO: always set this, or only when sending to another process with wantsReply=true?
    }
    
    internal init(code: EventIdentifier, returnID: AEReturnID) { // used by unflatten() below
        self.code = code
        self.returnID = returnID
    }
    
    // default SendOptions are .canInteract and .waitForReply
    public var interactionLevel: InteractionLevel = .canInteract
    public var canSwitchLayer: Bool = false // interaction may switch layer
    public var wantsReply: Bool = true      // this will automatically be true when sendAsync{…} is used to dispatch event
    public var timeout: TimeInterval = 120  // TO DO: currently unsupported; also, how should .defaultTimeout (-1) and .neverTimeout (-2) options be supported? (might consider 0 = never, -ve = default; also bear in mind that 'timo' attribute requires timeout in ticks, so +ve time intervals need multiplied by 60 and converted to Int32)
    
    public private(set) var attributes = [Attribute]() // miscellaneous attributes for which we don't [currently] provide dedicated properties
    public private(set) var parameters = [Parameter]()
    
    
    public let type: DescType = typeAppleEvent
    
    // TO DO: separate data for attributes and parameters? (not needed as long as AE build is atomic) how best to access attributes? (probably sufficient to iterate attribute data)
    public var data: Data {
        var result = Data([0x61, 0x65, 0x76, 0x74,          // type 'aevt'
                           0, 0, 0, 0,                      // bytes remaining (TBC) [4..<8]
                           0, 0, 0, 0,                      // reserved
                           0, 0, 0, 0,                      // reserved
                           0, 0, 0, 0,                      // offset to parameters (TBC) [16..<20]
                           0x00, 0x00, 0x00, 0x04])         // reserved (4)
        result += encodeUInt32(UInt32(parameters.count))      // parameter count
        result += Data([0, 0, 0, 0,                         // reserved
                        0, 0, 0, 0,                         // reserved
                        0, 0, 0, 0])                        // reserved
        let (eventClass, eventID) = eventIdentifier(self.code)
        result += encodeUInt32(eventClass)                    // event class
        result += encodeUInt32(eventID)                       // event ID
        result += Data([0, 0])                              // unused
        result += encodeInt16(returnID)                       // return ID
        result += Data(repeating: 0, count: 84)             // unused
        result += Data([0x61, 0x65, 0x76, 0x74,             // type 'aevt'
                        0x00, 0x01, 0x00, 0x01])            // version marker
                                                            // begin attributes
        if let target = self.target { // TO DO: what if target == nil? omit field, or use nullDescriptor?
            result += Data([0x61, 0x64, 0x64, 0x72])        // keyAddressAttr
            target.appendTo(containerData: &result)
        }
        result += Data([0x66, 0x72, 0x6F, 0x6D])            // keyOriginalAddressAttr
        let pid = ProcessInfo.processInfo.processIdentifier
        AddressDescriptor(processIdentifier: pid).appendTo(containerData: &result)
        result += Data([0x69, 0x6E, 0x74, 0x65,             // keyInteractLevelAttr
                        0x6C, 0x6F, 0x6E, 0x67,             // typeSInt32
                        0x00, 0x00, 0x00, 0x04,
                        0x00, 0x00, 0x00, self.interactionLevel.rawValue | (self.canSwitchLayer ? 0x40 : 0)])
        result += Data([0x72, 0x65, 0x70, 0x71,             // keyReplyRequestedAttr
                        0x6C, 0x6F, 0x6E, 0x67,             // typeSInt32
                        0x00, 0x00, 0x00, 0x04,
                        0x00, 0x00, 0x00, self.wantsReply ? 1 : 0]) // kAEWaitForReply/kAEQueueReply = true; kAENoReply = false
        
        // TO DO: should timeout attr be included here? (if so, need to ensure the same value is passed to send)
        result += Data([0x74, 0x69, 0x6D, 0x6F,             // keyTimeoutAttr
                        0x6C, 0x6F, 0x6E, 0x67,             // typeSInt32
                        0x00, 0x00, 0x00, 0x04])
        result += encodeInt32(120 * 60)                       // TO DO
        // keySubjectAttr = 0x7375626A // TO DO: should this be implemented as `var subject: QueryDescriptor?`? or left in misc attributes for parent code to deal with (it's arguably an [AppleScript-induced?] design wart: when an AppleScript command has a direct parameter AND an enclosing `tell` block, it can't pack the `tell` target as the direct parameter [its default behavior] as that's already given, so it sticks it in the 'subj' attribute instead; in py-appscript, the high-level appscript API does this automatically while the lower-level aem API leaves client code to set the 'subj' attribute itself)
        for (key, value) in attributes {                    // append any other attributes
            result += encodeUInt32(key)
            value.appendTo(containerData: &result)
        }
        result += Data([0x3b, 0x3b, 0x3b, 0x3b])            // end of attributes ';;;;'
        result[(result.startIndex + 16)..<(result.startIndex + 20)] = encodeUInt32(UInt32(result.count - 20)) // set offset to parameters
        for (key, value) in parameters {                    // append parameters
            result += encodeUInt32(key)
            value.appendTo(containerData: &result)
        }
        result[(result.startIndex + 4)..<(result.startIndex + 8)] = encodeUInt32(UInt32(result.count - 8)) // set remaining bytes
        return result
    }
    
    public func flatten() -> Data {
        return Data([0x64, 0x6c, 0x65, 0x32,          // format 'dle2'
                     0, 0, 0, 0]) + self.data         // align
    }
    
    public func appendTo(containerData: inout Data) {
        containerData += self.data
    }
    
    // TO DO: how best to implement this? also, is it worth implementing separate ReplyEventDescriptor specifically for working with reply events (which normally contain a fixed set of result/error/no parameters)?
    internal static func unflatten(_ data: Data, startingAt descStart: Int) throws -> AppleEventDescriptor { // TO DO: should this throw? (how else to deal with malformed AEDescs in general)
        if descStart != 0 { fatalError("TO DO") }
        if data[descStart..<(descStart + 8)] != Data([0x64, 0x6c, 0x65, 0x32,         // format 'dle2'
                                0, 0, 0, 0]) {                  // align
            throw AppleEventError(code: -1702, message: "dle2 header not found")
        }
        if data[(descStart + 8)..<(descStart + 12)] != Data([0x61, 0x65, 0x76, 0x74]) {     // type 'aevt'
            throw AppleEventError(code: -1703, message: "not an apple event")
        }
       // let _ = data.readUInt32(at: descStart + 12)                         // bytes remaining, then 8-bytes reserved
       // let _ = data.readUInt32(at: descStart + 24)                         // offset to parameters
        if data[(descStart + 28)..<(descStart + 32)] != Data([0x00, 0x00, 0x00, 0x04]) {    // reserved (4)
            throw AppleEventError(code: -1702, message: "unexpected bytes 28-32")
        }
        let parameterCount = data.readUInt32(at: descStart + 32)            // parameter count, then 12-bytes reserved
        let eventClass = data.readUInt32(at: descStart + 48)                // event class
        let eventID = data.readUInt32(at: descStart + 52)                   // event ID, then 2-bytes unused
        let returnID = try decodeInt16(data[(descStart + 58)..<(descStart + 60)])           // return ID, then 84-bytes unused
        if data[(descStart + 144)..<(descStart + 148)] != Data([0x61, 0x65, 0x76, 0x74]) {  // type 'aevt'
            throw AppleEventError(code: -1702, message: "unexpected bytes 132-136: \(literalFourCharCode(data.readUInt32(at: 132)))")
        }
        if data[(descStart + 148)..<(descStart + 152)] != Data([0x00, 0x01, 0x00, 0x01]) {  // version marker
            throw AppleEventError(code: -1706, message: "unexpected version marker")
        }
        var event = AppleEventDescriptor(code: eventIdentifier(eventClass, eventID), returnID: returnID)
        // iterate attributes and parameters to unpack them
        var offset = 152 // unflattenFirstDescriptor will add startIndex
        while true { // read up to end-of-attributes marker ';;;;'
            let key = data.readUInt32(at: offset)
            if key == 0x3b3b3b3b { break }
            let (descriptor, endOffset) = unflattenFirstDescriptor(in: data, startingAt: offset + 4)
            offset = endOffset
            do {
                switch descriptor.type {
                case keyAddressAttr:
                    event.target = descriptor as? AddressDescriptor // TO DO: sloppy; should probably throw if not a valid address desc (also need to check if nullDescriptor is a legitimate value for this attribute, although if it is then it'd still be preferable to omit entirely)
                //case keyOriginalAddressAttr: // the process that sent this event (it's only needed in server-side framework when creating a reply (aevt/ansr) event to send back; for now, just add to misc. attributes list)
                case keyInteractLevelAttr:
                    let flags = try unpackAsInt32(descriptor)
                    event.canSwitchLayer = (flags & 0x40) != 0 ? true : false
                    guard let level = InteractionLevel(rawValue: UInt8(flags & 0x30)) else { throw AppleEventError.corruptData }
                    event.interactionLevel = level
                case keyReplyRequestedAttr:
                    event.wantsReply = try unpackAsInt32(descriptor) != 0
                // case keyTimeoutAttr: // TO DO: implement
                default:
                    event.setAttribute(key, to: descriptor)
                }
            } catch {
                throw AppleEventError(code: error._code, message: "Bad \(literalFourCharCode(key)) attribute.", cause: error)
            }
        }
        offset += 4 // step over ';;;;' marker
        for _ in 0..<parameterCount {
            let key = data.readUInt32(at: offset)
            let (descriptor, endOffset) = unflattenFirstDescriptor(in: data, startingAt: offset + 4)
            event.setParameter(key, to: descriptor)
            offset = endOffset
        }
        return event
    }
}



public extension AppleEventDescriptor {
    
    mutating func setAttribute(_ key: DescType, to value: Descriptor) { // TO DO: throw/fail if key is a standard attribute already added in `var data: Data` accessor
        for i in 0..<self.attributes.count {
            if self.attributes[i].key == key {
                self.attributes[i].value = value
                return
            }
        }
        self.attributes.append((key, value))
    }
    
    mutating func setParameter(_ key: DescType, to value: Descriptor) {
        for i in 0..<self.parameters.count {
            if self.parameters[i].key == key {
                self.parameters[i].value = value
                return
            }
        }
        self.parameters.append((key, value))
    }
    
    // TO DO: would it be better for these to throw? (probably not, since higher-level API will want to generate human-readable error message, so won't benefit from error over nil)
    
    func attribute(_ key: DescType) -> Descriptor? {
        return self.attributes.first{ $0.key == key }?.value
    }
    
    func parameter(_ key: DescType) -> Descriptor? {
        return self.parameters.first{ $0.key == key }?.value
    }
}



// temporary kludge; allows us to send our homegrown AEs via established Carbon AESendMessage() API; aside from confirming that our code is reading and writing AEDesc data correctly (if not quirk-for-quirk compatible with AppleScript, then at least good enough to be understood by well-behaved apps), it gives us a benchmark to compare against as we implement our own Mach-AE bridging layer


public extension AppleEventDescriptor {
    
    // TO DO: might hedge our bets by keeping 'low-level' send() that returns raw reply descriptor, while providing a higher-level API that unpacks standard result/error responses and returns Descriptor? result or throws AEM/application error
    
    // TO DO: possible/practical to implement sendAsync method that takes completion callback? (this'll need more research; presumably we can create our own mach port to listen on if app doesn't already have a main event loop on which to receive incoming AEs [e.g. see keyReplyPortAttr usage in AESendThreadSafe.c, although that still invokes AESendMessage to dispatch outgoing event and return reply event, so doesn't give us any clues on how to implement our own sendSync/sendAsync methods])
    
    
    func send() -> (code: Int, reply: ReplyEventDescriptor?) {
        return carbonSend(event: self)
    }
}


public extension ReplyEventDescriptor {
    // TO DO: implement a separate ReplyEventDescriptor? reply events are purely one-way, and *should* only contain standard result/error properties (if any)
    
    // TO DO: implement reply(withResult:Descriptor?=nil)/reply(withError:Int,message:String?,etc) methods on AppleEventDescriptor that build and dispatch the reply (aevt/ansr) event as an atomic operation, minimizing opportunities for parent code to break things (we still have to trust client code to call these methods only on events it's received, not on events it's built itself, but given that this is still a relatively low-level API that may be a reasonable compromise)
    
    /*
     
     public let coreEventAnswer: EventIdentifier = 0x61657674_616E7372

     */
     
    var errorNumber: Int {
        if let desc = self.parameter(keyErrorNumber) {
            return (try? unpackAsInt(desc)) ?? -1
        } else {
            return 0
        }
    }
    
    var errorMessage: String? {
        if let desc = self.parameter(keyErrorString) {
            return try? unpackAsString(desc)
        } else {
            return nil
        }
    }
}
