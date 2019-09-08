//
//  AEMShim.swift
//
<<<<<<< HEAD:AppleEvents/CarbonShim.swift
//  workaround until we have a pure Mach implementation
//


#if canImport(Carbon)
import Carbon

func AEPrint(_ desc: inout AEDesc, _ msg: String) {}

#else
import MZCarbonShim
#endif
=======
//  workaround until we have a pure Mach implementation; see also AEMShim.m
//


import AEMShim
>>>>>>> af78e89499737721f62691f28fba42921edd74ea:AppleEvents/AEMShim.swift


func carbonDescriptor(from desc: Descriptor, to result: inout AEDesc) {
    var data = desc.flatten()
    let err = data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> Int in
        return Int(AEUnflattenDesc(ptr.baseAddress, &result))
    }
    if err != 0 { fatalError("AEUnflattenDesc error \(err), presumably due to malformed Descriptor.flatten() output.") }
}

// under MZ for some reason, passing AEDesc struct directly loses its data handle, so pass pointer to it
func nativeDescriptor(from aeDesc: inout AEDesc) -> Descriptor {
    let size = AESizeOfFlattenedDesc(&aeDesc)
    let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: size)
    let err = Int(AEFlattenDesc(&aeDesc, ptr, size, nil))
    if err != 0 { fatalError("AEFlattenDesc should not fail \(err)") }
    return unflattenDescriptor(Data(bytesNoCopy: ptr, count: size, deallocator: .none))
}

public func carbonSend(event: AppleEventDescriptor) -> (code: Int, reply: ReplyEventDescriptor?) {
    var aeEvent = AEDesc(descriptorType: typeNull, dataHandle: nil)
    var aeReply = AEDesc(descriptorType: typeNull, dataHandle: nil)
    defer { AEDisposeDesc(&aeEvent); AEDisposeDesc(&aeReply) }
    carbonDescriptor(from: event, to: &aeEvent)
    let flags = Int32(event.interactionLevel.rawValue | (event.canSwitchLayer ? 0x40 : 0) | (event.wantsReply ? 0x03 : 0x01))
    let err = Int(AESendMessage(&aeEvent, &aeReply, flags, Int(event.timeout > 0 ? (event.timeout * 60) : event.timeout)))
    return (err, nativeDescriptor(from: &aeReply) as? ReplyEventDescriptor)
}


// TO DO: worth making this async as standard? or better to provide separate async alternative? (most use-cases don't require async operation, and sync is slightly simpler and safer)
public func carbonReceive(message: UnsafeMutablePointer<mach_msg_header_t>, callback: AppleEventHandler) -> OSStatus {
    var aeEvent = AEDesc(descriptorType: typeNull, dataHandle: nil)
    var aeReply = AEDesc(descriptorType: typeNull, dataHandle: nil)
    defer { AEDisposeDesc(&aeEvent); AEDisposeDesc(&aeReply) }
    let err = AEDecodeMessage(message, &aeEvent, &aeReply)
    //AEPrint(&aeEvent, "carbonReceive decoded aeEvent:")
    if err == 0 {
        do {
            guard let event = nativeDescriptor(from: &aeEvent) as? AppleEventDescriptor else { return 8 }
            if let result = try callback(event) {
                var aeResult = AEDesc(descriptorType: typeNull, dataHandle: nil)
                carbonDescriptor(from: result, to: &aeResult)
                //AEPrint(&aeResult, "handler returned aeResult:")
                AEPutParamDesc(&aeReply, keyAEResult, &aeResult)
            }
        } catch { // TO DO: decide how best to implement application error reporting (standard errors - e.g. 'coercion failed', 'object not found' - might be provided as enum [this would also take any necessary message, failed object, params]; this would be based on standard 'AppleEventError' protocol, allowing apps to define their own error structs/classes should they need to report custom errors as well)
            // one option may be to define self-packing error protocol, or at least a protocol describing all standard error fields (plus one or two new additions, e.g. domain, traceback)
            // TO DO: error codes should be OSStatus, aka Int32, so should still pack as typeSInt32; Q. if code is out of 32-bit range, pack as typeSInt64? or throw/log console warning and return 32-bit error code? (apart from anything else, AppleScript doesn't support 64-bit ints so returning an out-of-range codes will cause problems there)
            var aeError = AEDesc(descriptorType: typeNull, dataHandle: nil)
            defer { AEDisposeDesc(&aeError) }
            carbonDescriptor(from: packAsInt32(Int32(error._code)), to: &aeError)
            AEPutParamDesc(&aeReply, keyErrorNumber, &aeError)
        }
        //AEPrint(&aeReply, "carbonReceive sending aeReply:")
        if aeReply.descriptorType == typeAppleEvent { AESendMessage(&aeReply, nil, 0x01, -1) }
    }
    return err
}

public func carbonPort() -> mach_port_t {
    return AEGetRegisteredMachPort()
}

