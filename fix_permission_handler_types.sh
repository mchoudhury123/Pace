#!/bin/bash

echo "Fixing permission handler type issues..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
ENUMS_FILE="${PLUGIN_PATH}/ios/Classes/PermissionHandlerEnums.h"

# First, let's check if the enums file exists
if [ ! -f "$ENUMS_FILE" ]; then
  echo "Error: PermissionHandlerEnums.h not found. Aborting."
  exit 1
fi

# Create backup of the enums file
echo "Creating backup of PermissionHandlerEnums.h..."
cp "${ENUMS_FILE}" "${ENUMS_FILE}.bak"

# First, let's update the SensorPermissionStrategy.m file to directly include PermissionHandlerEnums.h
SENSOR_STRATEGY="${PLUGIN_PATH}/ios/Classes/strategies/SensorPermissionStrategy.m"
echo "Ensuring PermissionHandlerEnums.h is directly included in SensorPermissionStrategy.m..."
cat > "${SENSOR_STRATEGY}" << 'EOL'
//
//  SensorPermissionStrategy.m
//  permission_handler
//
//  Created by Sebastian Roth on 5/21/20.
//

#import "SensorPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

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

# Now let's make sure the PermissionHandlerEnums.h is properly defined
echo "Updating PermissionHandlerEnums.h to ensure all enums are properly defined..."
cat > "${ENUMS_FILE}" << 'EOL'
//
//  PermissionHandlerEnums.h
//  permission_handler
//
//  Created by Razvan Lung on 15/02/2019.
//

// This is a direct copy from the permission_handler package
// and should be kept in sync.
// These enums should match the enums from the Platform Interface:
// https://github.com/Baseflow/flutter-permission-handler/blob/master/permission_handler_platform_interface/lib/src/permission_status.dart
// https://github.com/Baseflow/flutter-permission-handler/blob/master/permission_handler_platform_interface/lib/src/service_status.dart

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
EOL

# Let's also make sure the PermissionStrategy.h is correctly defined
STRATEGY_HEADER="${PLUGIN_PATH}/ios/Classes/PermissionStrategy.h"
echo "Updating PermissionStrategy.h..."
cp "${STRATEGY_HEADER}" "${STRATEGY_HEADER}.bak"
cat > "${STRATEGY_HEADER}" << 'EOL'
//
//  PermissionStrategy.h
//  permission_handler
//
//  Created by Razvan Lung on 15/02/2019.
//

#import <Foundation/Foundation.h>
#import "PermissionHandlerEnums.h"

@protocol PermissionStrategy <NSObject>

- (void)requestPermission:(PermissionGroup)permission completion:(PermissionStatusCallback)completion;
- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission;
- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission;

@end
EOL

echo "Fixing permission handler type issues completed."
echo "Please rebuild your iOS project now." 