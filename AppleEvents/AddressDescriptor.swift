//
//  AddressDescriptor.swift
//

import Foundation



public struct AddressDescriptor: Descriptor, Scalar, CustomDebugStringConvertible {
    
    public let type: DescType
    public let data: Data
    
    public var debugDescription: String {
        var value: Any? = nil
        switch self.type {
        case typeProcessSerialNumber:   value = try? decodeUInt64(self.data)
        case typeKernelProcessID:       value = try? self.processIdentifier()
        case typeApplicationBundleID:   value = try? self.bundleIdentifier().debugDescription
        case typeApplicationURL:        value = try? self.applicationURL().debugDescription
        default:                        ()
        }
        return "<\(Swift.type(of: self)) \(literalFourCharCode(self.type)) \(value ?? "...")>"
    }
}


public extension AddressDescriptor {
    
    init() { // current application
        self.type = typeProcessSerialNumber
        self.data = Data([0,0,0,0,0,0,0,2]) // equivalent to `ProcessSerialNumber(0,kCurrentProcess)`, aka UInt64(bigEndian:2)
    }
    
    init(processIdentifier value: pid_t) {
        self.type = typeKernelProcessID
        self.data = encodeInt32(value) // pid_t = Int32
    }
    
    func processIdentifier() throws -> pid_t {
        switch self.type {
        case typeKernelProcessID:
            return try decodeInt32(self.data)
        default:
            throw AppleEventError(code: -1701)
        }
    }
    
    init(bundleIdentifier value: String) throws {
        self.type = typeApplicationBundleID
        self.data = encodeUTF8String(value)
    }
    
    func bundleIdentifier() throws -> String {
        switch self.type {
        case typeApplicationBundleID:
            guard let result = decodeUTF8String(self.data) else { throw AppleEventError.corruptData }
            return result
        default:
            throw AppleEventError(code: -1701)
        }
    }
    
    init(applicationURL value: URL) throws {
        // TO DO: check URL is valid (file/eppc) and throw if not
        self.type = typeApplicationURL
        self.data = encodeUTF8String(value.absoluteString)
    }
    
    func applicationURL() throws -> URL {
        switch self.type {
        case typeApplicationURL:
            guard let string = decodeUTF8String(self.data), let result = URL(string: string) else {
                throw AppleEventError(code: -1702)
            }
            return result
        default:
            throw AppleEventError(code: -1701)
        }
    }
}

