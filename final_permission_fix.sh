#!/bin/bash

echo "Fixing permission handler plugin with a clean implementation..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
CLASSES_DIR="${PLUGIN_PATH}/ios/Classes"
STRATEGIES_DIR="${CLASSES_DIR}/strategies"

# Make a backup of the original plugin
echo "Creating backup of the original plugin..."
BACKUP_DIR="${PLUGIN_PATH}_backup_$(date +%Y%m%d%H%M%S)"
cp -r "${PLUGIN_PATH}" "${BACKUP_DIR}"

# Clean up the plugin directory structure
echo "Cleaning up plugin directory structure..."
rm -rf "${CLASSES_DIR}/shared"
mkdir -p "${CLASSES_DIR}"
mkdir -p "${STRATEGIES_DIR}"

# Create a new PermissionHandlerEnums.h file
echo "Creating PermissionHandlerEnums.h..."
cat > "${CLASSES_DIR}/PermissionHandlerEnums.h" << 'EOL'
//
//  PermissionHandlerEnums.h
//  permission_handler_apple
//

#ifndef PermissionHandlerEnums_h
#define PermissionHandlerEnums_h

typedef NS_ENUM(int, PermissionGroup) {
    PermissionGroupCalendar = 0,
    PermissionGroupCamera,
    PermissionGroupContacts,
    PermissionGroupLocation,
    PermissionGroupLocationAlways,
    PermissionGroupLocationWhenInUse,
    PermissionGroupMediaLibrary,
    PermissionGroupMicrophone,
    PermissionGroupPhone,
    PermissionGroupPhotos,
    PermissionGroupPhotosAddOnly,
    PermissionGroupReminders,
    PermissionGroupSensors,
    PermissionGroupSms,
    PermissionGroupSpeech,
    PermissionGroupStorage,
    PermissionGroupIgnoreBatteryOptimizations,
    PermissionGroupNotification,
    PermissionGroupAccessMediaLocation,
    PermissionGroupActivityRecognition,
    PermissionGroupUnknown,
    PermissionGroupBluetooth,
    PermissionGroupManageExternalStorage,
    PermissionGroupSystemAlertWindow,
    PermissionGroupRequestInstallPackages,
    PermissionGroupAppTrackingTransparency,
    PermissionGroupCriticalAlerts,
    PermissionGroupAccessNotificationPolicy,
    PermissionGroupBluetoothScan,
    PermissionGroupBluetoothAdvertise,
    PermissionGroupBluetoothConnect,
    PermissionGroupNearbyWifiDevices,
    PermissionGroupVideos,
    PermissionGroupAudio,
    PermissionGroupScheduleExactAlarm,
    PermissionGroupCalendarFullAccess,
    PermissionGroupAssistant,
    PermissionGroupBackgroundRefresh,
};

typedef NS_ENUM(int, PermissionStatus) {
    PermissionStatusDenied = 0,
    PermissionStatusGranted,
    PermissionStatusRestricted,
    PermissionStatusLimited,
    PermissionStatusPermanentlyDenied,
    PermissionStatusProvisional,
};

typedef NS_ENUM(int, ServiceStatus) {
    ServiceStatusDisabled = 0,
    ServiceStatusEnabled,
    ServiceStatusNotApplicable,
};

typedef void (^PermissionStatusCallback)(PermissionStatus permissionStatus);
typedef void (^ServiceStatusCallback)(ServiceStatus serviceStatus);

#endif /* PermissionHandlerEnums_h */
EOL

# Create PermissionStrategy.h
echo "Creating PermissionStrategy.h..."
cat > "${CLASSES_DIR}/PermissionStrategy.h" << 'EOL'
//
//  PermissionStrategy.h
//  permission_handler_apple
//

#ifndef PermissionStrategy_h
#define PermissionStrategy_h

#import <Foundation/Foundation.h>
#import "PermissionHandlerEnums.h"

@protocol PermissionStrategy <NSObject>

- (void)requestPermission:(PermissionGroup)permission completion:(PermissionStatusCallback)completion;
- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission;
- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission;

@end

#endif /* PermissionStrategy_h */
EOL

# Create SensorPermissionStrategy.h
echo "Creating SensorPermissionStrategy.h..."
cat > "${STRATEGIES_DIR}/SensorPermissionStrategy.h" << 'EOL'
//
//  SensorPermissionStrategy.h
//  permission_handler_apple
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import "../PermissionStrategy.h"

@interface SensorPermissionStrategy : NSObject <PermissionStrategy>
@end
EOL

# Create SensorPermissionStrategy.m
echo "Creating SensorPermissionStrategy.m..."
cat > "${STRATEGIES_DIR}/SensorPermissionStrategy.m" << 'EOL'
//
//  SensorPermissionStrategy.m
//  permission_handler_apple
//

#import "SensorPermissionStrategy.h"
#import "../PermissionHandlerEnums.h"

#if PERMISSION_SENSORS

@implementation SensorPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    if (@available(iOS 11.0, *)) {
        CMAuthorizationStatus status = [CMMotionActivityManager authorizationStatus];
        
        switch (status) {
            case CMAuthorizationStatusNotDetermined:
                return PermissionStatusDenied;
            case CMAuthorizationStatusRestricted:
                return PermissionStatusRestricted;
            case CMAuthorizationStatusDenied:
                return PermissionStatusDenied;
            case CMAuthorizationStatusAuthorized:
                return PermissionStatusGranted;
        }
    }
    
#if TARGET_OS_OSX
    // On macOS, sensors are always unavailable
    return PermissionStatusPermanentlyDenied;
#else
    // Default to denied for iOS versions that don't support CMMotionActivityManager
    return PermissionStatusDenied;
#endif
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
#if TARGET_OS_OSX
    return ServiceStatusNotApplicable;
#else
    return ServiceStatusEnabled;
#endif
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    if (@available(iOS 11.0, *)) {
        CMMotionActivityManager *manager = [[CMMotionActivityManager alloc] init];
        NSDate *now = [NSDate date];
        
        [manager queryActivityStartingFromDate:now
                                       toDate:now
                                      toQueue:[NSOperationQueue mainQueue]
                                  withHandler:^(NSArray<CMMotionActivity *> * _Nullable activities, NSError * _Nullable error) {
            
            if (error != nil && error.code == CMErrorMotionActivityNotAuthorized) {
                completion(PermissionStatusDenied);
                return;
            }
            
            completion(PermissionStatusGranted);
        }];
        
        return;
    }
    
#if TARGET_OS_OSX
    // On macOS, sensors are always unavailable
    completion(PermissionStatusPermanentlyDenied);
#else
    // Default to denied for iOS versions that don't support CMMotionActivityManager
    completion(PermissionStatusDenied);
#endif
}

@end

#else

@implementation SensorPermissionStrategy
@end

#endif
EOL

# Create a proper public umbrella header for the plugin
echo "Creating public umbrella header..."
cat > "${PLUGIN_PATH}/ios/permission_handler_apple.h" << 'EOL'
#import <Foundation/Foundation.h>

//! Project version number for permission_handler_apple.
FOUNDATION_EXPORT double permission_handler_appleVersionNumber;

//! Project version string for permission_handler_apple.
FOUNDATION_EXPORT const unsigned char permission_handler_appleVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <permission_handler_apple/PublicHeader.h>

#import "Classes/PermissionHandlerEnums.h"
#import "Classes/PermissionStrategy.h"
EOL

# Create module map
echo "Creating module map..."
mkdir -p "${PLUGIN_PATH}/ios/build"
cat > "${PLUGIN_PATH}/ios/build/module.modulemap" << 'EOL'
framework module permission_handler_apple {
  umbrella header "../permission_handler_apple.h"
  
  export *
  module * { export * }
}
EOL

# Fix the Xcode project's public headers settings
echo "Cleaning up build artifacts..."
cd ~/fundracer_app_new/ios
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/*
cd ..
flutter clean

# Reinstall the pods
echo "Reinstalling pods..."
cd ios
pod install --repo-update

echo "Permission handler headers fixed. Now close Xcode, reopen it, and rebuild the project." 