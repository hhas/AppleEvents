//
//  AEMShim.h
//
//  various bits of CoreServices/AE.framework that AppleEvents.framework still needs until fully ported over to Mach APIs
//

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>


//! Project version number for AEMShim.
FOUNDATION_EXPORT double AEMShimVersionNumber;

//! Project version string for AEMShim.
FOUNDATION_EXPORT const unsigned char AEMShimVersionString[];

#ifndef __AE__

typedef FourCharCode                    DescType;
typedef FourCharCode                    AEKeyword;
typedef SInt32                          AESendMode;

typedef struct OpaqueAEDataStorageType* AEDataStorageType;

typedef AEDataStorageType *             AEDataStorage;

typedef struct AEDesc {
    DescType            descriptorType;
    AEDataStorage       dataHandle;
} AEDesc;

typedef AEDesc                          AEDescList;
typedef AEDescList                      AERecord;
typedef AEDesc                          AEAddressDesc;
typedef AERecord                        AppleEvent;

CF_ENUM(DescType) {
    typeNull        = 'null',
    typeAppleEvent  = 'aevt',
    keyErrorNumber  = 'errn',
    keyErrorString  = 'errs',
    keyAEResult     = '----'
};

#endif

extern Size         AESizeOfFlattenedDesc(const AEDesc *theAEDesc);
extern OSStatus     AEFlattenDesc(const AEDesc *theAEDesc, Ptr buffer, Size bufferSize, Size *actualSize);
extern OSStatus     AEUnflattenDesc(const void *buffer, AEDesc *result);
extern OSErr        AEDisposeDesc(AEDesc *theAEDesc);
extern OSErr        AEPutParamDesc(AppleEvent *theAppleEvent, AEKeyword theAEKeyword, const AEDesc *theAEDesc);
extern mach_port_t  AEGetRegisteredMachPort(void);
extern OSStatus     AEDecodeMessage(mach_msg_header_t *header, AppleEvent *event, AppleEvent *reply);
extern OSStatus     AESendMessage(const AppleEvent *event, AppleEvent *reply, AESendMode sendMode, long timeOutInTicks);

extern OSStatus     AEPrint(const AEDesc *desc, const char *msg);

