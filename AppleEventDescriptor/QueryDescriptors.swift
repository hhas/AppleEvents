//
//  QueryDescriptors.swift
//

import Foundation

// TO DO: implement here, or in SwiftAutomation? (TBH, SA needs another rework to use this new Descriptor API, so might be as well just to implement structs here as replacements to SA's Query classes; if nothing else it will be interesting to see which of the three implementations performs best, given different memory management and interaction models (Swift classes backed by Cocoa classes wrapping mutable single-owner C structs+handles, vs Swift classes backed by Swift structs wrapping mutable single-owner C structs+handles, vs Swift structs holding immutable reference-backed Data values))

// RootDescriptor (App, Con, Its, Custom)
// ObjectDescriptor
// MultipleObjectDescriptor
// InsertionDescriptor
// RangeDescriptor
// ComparisonDescriptor
// LogicDescriptor





/*
public extension AEDesc { // query components
    
    // caution: constructors should not take ownership of supplied AEDescs
    
    init(desiredClass: DescType, container: AEDesc, keyForm: DescType, keyData: AEDesc) {
        var container = container, keyData = keyData, desc = nullDescriptor
        try! throwIfError(CreateObjSpecifier(desiredClass, &container, keyForm, &keyData, false, &desc))
        self = desc
    }
    
    init(insertionLocation position: DescType, container: AEDesc) {
        let desc = AEDesc.record(as: typeInsertionLoc)
        try! desc.setParameter(keyAEObject, to: container)
        try! desc.packFixedSizeParameter(keyAEPosition, value: position, as: typeEnumerated)
        self = desc
    }
    
    init(rangeStart: AEDesc, rangeStop: AEDesc) {
        var rangeStart = rangeStart, rangeStop = rangeStop, desc = nullDescriptor
        try! throwIfError(CreateRangeDescriptor(&rangeStart, &rangeStop, false, &desc))
        self = desc
    }
    
    init(comparisonTest: DescType, operand1: AEDesc, operand2: AEDesc) {
        var operand1 = operand1, operand2 = operand2, desc = nullDescriptor
        try! throwIfError(CreateCompDescriptor(comparisonTest, &operand1, &operand2, false, &desc))
        self = desc
        
    }
    init(logicalTest: DescType, operands: AEDescList) {
        var operands = operands, desc = nullDescriptor
        try! throwIfError(CreateLogicalDescriptor(&operands, logicalTest, false, &desc))
        self = desc
    }
    
    // caution: calling code has ownership of returned AEDescs so must ensure their disposal once no longer needed
    // these methods should only throw if called on wrong AEDesc type, or if descriptor is malformed
    
    func objectSpecifier() throws -> (desiredClass: DescType, container: AEDesc, keyForm: DescType, keyData: AEDesc) {
        var container = nullDescriptor
        do {
            let desiredClass = try self.unpackFixedSizeParameter(AEKeyword(keyAEDesiredClass), as: typeType) as DescType
            let keyForm = try self.unpackFixedSizeParameter(AEKeyword(keyAEKeyForm), as: typeEnumerated) as DescType
            container = try self.parameter(AEKeyword(keyAEContainer))
            return (desiredClass, container, keyForm, try self.parameter(AEKeyword(keyAEKeyData)))
        } catch {
            container.dispose()
            throw error
        }
    }
    
    func insertionLocation() throws -> (container: AEDesc, position: DescType) {
        let position = try self.unpackFixedSizeParameter(keyAEPosition, as: typeEnumerated) as DescType
        return (try self.parameter(keyAEObject), position)
    }
    
    func rangeDescriptor() throws -> (rangeStart: AEDesc, rangeStop: AEDesc) {
        var rangeStart = nullDescriptor
        do {
            rangeStart = try self.parameter(AEKeyword(keyAERangeStart)) // TO DO: `as: typeObjSpecifier`?
            return (rangeStart, try self.parameter(AEKeyword(keyAERangeStop))) // TO DO: `as: typeObjSpecifier`?
        } catch {
            rangeStart.dispose()
            throw error
        }
    }
    
    func comparisonTest() throws -> (operator: DescType, operand1: AEDesc, operand2: AEDesc) {
        // TO DO: how much validation should these methods perform? (see also notes in AppData)
        var operand1 = nullDescriptor
        do {
            let op = try self.unpackFixedSizeParameter(AEKeyword(keyAECompOperator), as: typeEnumerated) as DescType
            operand1 = try self.parameter(AEKeyword(keyAEObject1))
            return (op, operand1, try self.parameter(AEKeyword(keyAEObject2)))
        } catch {
            operand1.dispose()
            throw error
        }
    }
    
    func logicalTest() throws -> (operator: DescType, operands: AEDescList) {
        let op = try self.unpackFixedSizeParameter(AEKeyword(keyAELogicalOperator), as: typeEnumerated) as DescType
        return (op, try self.parameter(AEKeyword(keyAEObject), as: typeAEList))
    }
}

*/
