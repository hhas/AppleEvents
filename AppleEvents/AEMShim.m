//
//  AEMShim.m
//

// CoreServices.framework should be present on all platforms, but will only include AE* symbols on macOS

#import "AEMShim.h"


#define LOAD { if (shouldLoad) loadCarbon(); }

#define BIND(name) { if (!((ptr_##name) = CFBundleGetFunctionPointerForName(framework, CFSTR(#name)))) exit(5); }


char *coreServicesPath = "/System/Library/Frameworks/CoreServices.framework";



static Size         (*ptr_AESizeOfFlattenedDesc)(const AEDesc *theAEDesc);
static OSStatus     (*ptr_AEFlattenDesc)(const AEDesc *theAEDesc, Ptr buffer, Size bufferSize, Size *actualSize);
static OSStatus     (*ptr_AEUnflattenDesc)(const void *buffer, AEDesc *result);
static OSErr        (*ptr_AEDisposeDesc)(AEDesc *theAEDesc);
static OSErr        (*ptr_AEPutParamDesc)(AppleEvent *theAppleEvent, AEKeyword theAEKeyword, const AEDesc *theAEDesc);
static mach_port_t  (*ptr_AEGetRegisteredMachPort)(void);
static OSStatus     (*ptr_AEDecodeMessage)(mach_msg_header_t *header, AppleEvent *event, AppleEvent *reply);
static OSStatus     (*ptr_AESendMessage)(const AppleEvent *event, AppleEvent *reply, AESendMode sendMode, long timeOutInTicks);
static OSStatus     (*ptr_AEPrintDescToHandle)(const AEDesc *desc, Handle *result);


int shouldLoad = 1;

void loadCarbon(void) {
    shouldLoad = 0;
    CFURLRef frameworkURL = CFURLCreateFromFileSystemRepresentation(nil, (UInt8 *)coreServicesPath, strlen(coreServicesPath), true);
    CFBundleRef framework = CFBundleCreate(nil, frameworkURL);
    CFRelease(frameworkURL);
    if (framework) {
        BIND(AESizeOfFlattenedDesc);
        BIND(AEFlattenDesc);
        BIND(AEUnflattenDesc);
        BIND(AEDisposeDesc);
        BIND(AEPutParamDesc);
        BIND(AEGetRegisteredMachPort);
        BIND(AEDecodeMessage);
        BIND(AESendMessage);
        BIND(AEPrintDescToHandle);
        CFRelease(framework);
    }
}


extern Size AESizeOfFlattenedDesc(const AEDesc *theAEDesc) {
    LOAD; return (*ptr_AESizeOfFlattenedDesc)(theAEDesc);
}
extern OSStatus AEFlattenDesc(const AEDesc *theAEDesc, Ptr buffer, Size bufferSize, Size *actualSize) {
    LOAD; return (*ptr_AEFlattenDesc)(theAEDesc, buffer, bufferSize, actualSize);
}
extern OSStatus AEUnflattenDesc(const void *buffer, AEDesc *result) {
    LOAD; return (*ptr_AEUnflattenDesc)(buffer, result);
}
extern OSErr AEDisposeDesc(AEDesc *theAEDesc) {
    LOAD; return (*ptr_AEDisposeDesc)(theAEDesc);
}
extern OSErr AEPutParamDesc(AppleEvent *theAppleEvent, AEKeyword theAEKeyword, const AEDesc *theAEDesc) {
    LOAD; return (*ptr_AEPutParamDesc)(theAppleEvent, theAEKeyword, theAEDesc);
}
extern mach_port_t AEGetRegisteredMachPort(void) {
    LOAD; return (*ptr_AEGetRegisteredMachPort)();
}
extern OSStatus AEDecodeMessage(mach_msg_header_t *header, AppleEvent *event, AppleEvent *reply) {
    LOAD; return (*ptr_AEDecodeMessage)(header, event, reply);
}
extern OSStatus AESendMessage(const AppleEvent *event, AppleEvent *reply, AESendMode sendMode, long timeOutInTicks) {
    AEPrint(event, "AESendMessage event");
    LOAD; return (*ptr_AESendMessage)(event, reply, sendMode, timeOutInTicks);
}


extern OSStatus AEPrint(const AEDesc *desc, const char *msg) { // debugging use only (leaks memory)
    LOAD;
    Handle h = NULL; // DisposeHandle() is deprecated, so leak the returned char**
    OSStatus err = (*ptr_AEPrintDescToHandle)(desc, &h);
    if (!err) { NSLog(@"AEPrint %s: %s\n", msg, *h); }
    return err;
}

