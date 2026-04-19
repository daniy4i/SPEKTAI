#ifndef lannaapp_Bridging_Header_h
#define lannaapp_Bridging_Header_h

#ifdef __has_include
#if __has_include("Vendor/HeyCyan/QCCentralManager.h")
#import "Vendor/HeyCyan/QCCentralManager.h"
#elif __has_include("Glasses/QCCentralManager.h")
#import "Glasses/QCCentralManager.h"
#endif

#if __has_include(<QCSDK/QCSDKManager.h>)
#import <QCSDK/QCSDKManager.h>
#import <QCSDK/QCSDKCmdCreator.h>
#import <QCSDK/QCVersionHelper.h>
#endif
#endif

#endif /* lannaapp_Bridging_Header_h */
