//
//  MZCarbonShim.h
//

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>


//! Project version number for MZCarbonShim.
FOUNDATION_EXPORT double MZCarbonShimVersionNumber;

//! Project version string for MZCarbonShim.
FOUNDATION_EXPORT const unsigned char MZCarbonShimVersionString[];



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


extern Size         AESizeOfFlattenedDesc(const AEDesc *theAEDesc);
extern OSStatus     AEFlattenDesc(const AEDesc *theAEDesc, Ptr buffer, Size bufferSize, Size *actualSize);
extern OSStatus     AEUnflattenDesc(const void *buffer, AEDesc *result);
extern OSErr        AEDisposeDesc(AEDesc *theAEDesc);
extern OSErr        AEPutParamDesc(AppleEvent *theAppleEvent, AEKeyword theAEKeyword, const AEDesc *theAEDesc);
extern mach_port_t  AEGetRegisteredMachPort(void);
extern OSStatus     AEDecodeMessage(mach_msg_header_t *header, AppleEvent *event, AppleEvent *reply);
extern OSStatus     AESendMessage(const AppleEvent *event, AppleEvent *reply, AESendMode sendMode, long timeOutInTicks);

extern OSStatus     AEPrint(const AEDesc *desc, const char *msg);

CF_ENUM(DescType) {
    typeNull        = 'null',
    typeAppleEvent  = 'aevt',
    keyErrorNumber  = 'errn',
    keyErrorString  = 'errs',
    keyAEResult     = '----'
};

