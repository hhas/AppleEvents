//
//  AppleEventError.swift
//

import Foundation


internal let descriptionForError: [Int:String] = [
    // OS errors
    -34: "Disk is full.",
    -35: "Disk wasn't found.",
    -37: "Bad name for file.",
    -38: "File wasn't open.",
    -39: "End of file error.",
    -42: "Too many files open.",
    -43: "File wasn't found.",
    -44: "Disk is write protected.",
    -45: "File is locked.",
    -46: "Disk is locked.",
    -47: "File is busy.",
    -48: "Duplicate file name.",
    -49: "File is already open.",
    -50: "Parameter error.",
    -51: "File reference number error.",
    -61: "File not open with write permission.",
    -108: "Out of memory.",
    -120: "Folder wasn't found.",
    -124: "Disk is disconnected.",
    -128: "User canceled.",
    -192: "A resource wasn't found.",
    -600: "Application isn't running.",
    -601: "Not enough room to launch application with special requirements.",
    -602: "Application is not 32-bit clean.",
    -605: "More memory is needed than is specified in the size resource.",
    -606: "Application is background-only.",
    -607: "Buffer is too small.",
    -608: "No outstanding high-level event.",
    -609: "Connection is invalid.",
    -610: "No user interaction allowed.",
    -904: "Not enough system memory to connect to remote application.",
    -905: "Remote access is not allowed.",
    -906: "Application isn't running or program linking isn't enabled.",
    -915: "Can't find remote machine.",
    -30720: "Invalid date and time.",
    // AE errors
    -1700: "Can't make some data into the expected type.",
    -1701: "Some parameter is missing for command.",
    -1702: "Some data could not be read.",
    -1703: "Some data was the wrong type.",
    -1704: "Some parameter was invalid.",
    -1705: "Operation involving a list item failed.",
    -1706: "Need a newer version of the Apple Event Manager.",
    -1707: "Event isn't an Apple event.",
    -1708: "Application could not handle this command.",
    -1709: "AEResetTimer was passed an invalid reply.",
    -1710: "Invalid sending mode was passed.",
    -1711: "User canceled out of wait loop for reply or receipt.",
    -1712: "Apple event timed out.",
    -1713: "No user interaction allowed.",
    -1714: "Wrong keyword for a special function.",
    -1715: "Some parameter wasn't understood.",
    -1716: "Unknown Apple event address type.",
    -1717: "The handler is not defined.",
    -1718: "Reply has not yet arrived.",
    -1719: "Can't get reference. Invalid index.",
    -1720: "Invalid range.",
    -1721: "Wrong number of parameters for command.",
    -1723: "Can't get reference. Access not allowed.",
    -1725: "Illegal logical operator called.",
    -1726: "Illegal comparison or logical.",
    -1727: "Expected a reference.",
    -1728: "Can't get reference.",
    -1729: "Object counting procedure returned a negative count.",
    -1730: "Container specified was an empty list.",
    -1731: "Unknown object type.",
    -1739: "Attempting to perform an invalid operation on a null descriptor.",
    -1741: "Buffer for AEFlattenDesc too small.",

    // Application scripting errors
    -10000: "Apple event handler failed.",
    -10001: "Type error.",
    -10002: "Invalid key form.",
    -10003: "Can't set reference to given value. Access not allowed.",
    -10004: "A privilege violation occurred.",
    -10005: "The read operation wasn't allowed.",
    -10006: "Can't set reference to given value.",
    -10007: "The index of the event is too large to be valid.",
    -10008: "The specified object is a property, not an element.",
    -10009: "Can't supply the requested descriptor type for the data.",
    -10010: "The Apple event handler can't handle objects of this class.",
    -10011: "Couldn't handle this command because it wasn't part of the current transaction.",
    -10012: "The transaction to which this command belonged isn't a valid transaction.",
    -10013: "There is no user selection.",
    -10014: "Handler only handles single objects.",
    -10015: "Can't undo the previous Apple event or user action.",
    -10023: "Enumerated value is not allowed for this property.",
    -10024: "Class can't be an element of container.",
    -10025: "Illegal combination of properties settings."
]



public struct AppleEventError: Error, CustomStringConvertible {
    public let domain = "SwiftAutomation"
    public let _code: Int // the OSStatus if known, or generic error code if not
    public let cause: Error? // the error that triggered this failure, if any
    
    let _message: String?
    
    public init(code: Int, message: String? = nil, cause: Error? = nil) {
        self._code = code
        self._message = message
        self.cause = cause
    }
    
    public init(message: String, cause: Error) { // chain errors to provide contextual information
        self.init(code: cause._code, message: message, cause: cause)
    }
    
    public var code: Int { return self._code }
    public var message: String? { return self._message } // TO DO: make non-optional?
    
    func description(_ previousCode: Int, separator: String = " ") -> String {
        let msg = self.message ?? descriptionForError[self._code]
        var string = self._code == previousCode ? "" : "Error \(self._code)\(msg == nil ? "." : ": ")"
        if let msg = msg { string += msg }
        if let error = self.cause as? AppleEventError {
            string += "\(separator)\(error.description(self._code))"
        } else if let error = self.cause {
            string += "\(separator)\(error)"
        }
        return string
    }
    
    public var description: String {
        return self.description(0)
    }
}

public extension AppleEventError {
    // TO DO: check these names are correct; what other codes?
    static let unsupportedCoercion = AppleEventError(code: -1700) // TO DO: what about taking desc types as arguments?
    static let missingParameter = AppleEventError(code: -1701)
    static let corruptData = AppleEventError(code: -1702)
    static let unsupportedType = AppleEventError(code: -1702)
    static let invalidParameter = AppleEventError(code: -1704)
    static let unsupportedAppleEvent = AppleEventError(code: -1708)
    static let appleEventTimedOut = AppleEventError(code: -1712)
    static let noUserInteraction = AppleEventError(code: -1713)
    static let invalidIndex = AppleEventError(code: -1719)
    static let invalidRange = AppleEventError(code: -1720)
    static let invalidParameterCount = AppleEventError(code: -1721)
    static let referenceNotFound = AppleEventError(code: -1728)
}
