//
//  AppleEventDescriptor.swift
//

import Foundation

public typealias AEReturnID = Int16
public typealias AETransactionID = Int32
public typealias AEEventClass = OSType
public typealias AEEventID = OSType


let kAutoGenerateReturnID: AEReturnID = -1
let kAnyTransactionID: AETransactionID = 0



public struct AppleEventDescriptor: Descriptor {
    
    public var debugDescription: String {
        return "<AppleEventDescriptor \(literalFourCharCode(self.eventClass))/\(literalFourCharCode(self.eventID))>"
    }
    
    public let type: DescType = typeAppleEvent
    
    // TO DO: separate data for attributes and parameters? (not needed as long as AE build is atomic) how best to access attributes? (probably sufficient to iterate attribute data)
    public let data = Data() // TO DO
    
    static public func unflatten(_ data: Data) -> AppleEventDescriptor { // TO DO: should this throw? (how else to deal with malformed AEDescs in general)
        fatalError("TO DO")
    }
    
    public func flatten() -> Data {
        return Data()
    }
    
    public func appendTo(containerData: inout Data) {
        // TO DO: here be dragons
    }
    
    // TO DO: could argue for returnID/transactionID being separately set; main problem is how to supply attributes and params
    init(eventClass: AEEventClass, eventID: AEEventID, target: AddressDescriptor? = nil,
         returnID: AEReturnID = kAutoGenerateReturnID, transactionID: AETransactionID = kAnyTransactionID) {
    }
    
    var eventClass: AEEventClass {
        return 0
    }
    var eventID: AEEventID {
        return 0
    }
}



public extension AppleEventDescriptor {
    
    struct SendOptions: OptionSet {
        
        public let rawValue: AESendMode
        
        public static let noReply                = SendOptions(rawValue: 0x00000001) /* sender doesn't want a reply to event */
        public static let queueReply             = SendOptions(rawValue: 0x00000002) /* sender wants a reply but won't wait */
        public static let waitForReply           = SendOptions(rawValue: 0x00000003) /* sender wants a reply and will wait */
    //  public static let dontReconnect          = SendOptions(rawValue: 0x00000080 /* don't reconnect if there is a sessClosedErr from PPCToolbox */
    //  public static let wantReceipt            = SendOptions(rawValue: 0x00000200 /* (nReturnReceipt) sender wants a receipt of message */
        public static let neverInteract          = SendOptions(rawValue: 0x00000010) /* server should not interact with user */
        public static let canInteract            = SendOptions(rawValue: 0x00000020) /* server may try to interact with user */
        public static let alwaysInteract         = SendOptions(rawValue: 0x00000030) /* server should always interact with user where appropriate */
        public static let canSwitchLayer         = SendOptions(rawValue: 0x00000040) /* interaction may switch layer */
        public static let dontRecord             = SendOptions(rawValue: 0x00001000) /* don't record this event */
        public static let dontExecute            = SendOptions(rawValue: 0x00002000) /* don't send the event for recording */
        public static let processNonReplyEvents  = SendOptions(rawValue: 0x00008000) /* allow processing of non-reply events while awaiting synchronous AppleEvent reply */
        public static let dontAnnotate           = SendOptions(rawValue: 0x00010000) /* if set, don't automatically add any sandbox or other annotations to the event */
        public static let defaultOptions         = SendOptions(rawValue: 0x00000023) // [.waitForReply, .canInteract]
        
        public init(rawValue: AESendMode) { self.rawValue = rawValue }
    }
    
    
    func sendEvent(options: SendOptions = .defaultOptions, timeout: TimeInterval = -1) -> (reply: AppleEventDescriptor?, code: Int) { // TO DO: how to provide .neverTimeout, .defaultTimeout constants? (probably best to define timeout arg as enum) // TO DO: return (AEDesc,OSStatus) instead of throwing
        return (nil, 0)
    }
    
    // TO DO: implement a separate ReplyEventDescriptor? reply events aren't built for sending, and outgoing events don't have error number or message parameters
    var errorNumber: Int {
        return 0
    }
    
    var errorMessage: String? {
        return nil
    }

}
