#!/bin/bash

echo "Fixing missing header paths..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGIES_DIR="${PLUGIN_PATH}/ios/Classes/strategies"
CLASSES_DIR="${PLUGIN_PATH}/ios/Classes"
SHARED_DIR="${CLASSES_DIR}/shared"

# Make sure shared directory exists
mkdir -p "${SHARED_DIR}"

# First, check if our target files exist in the shared directory
if [ ! -f "${SHARED_DIR}/PermissionStrategy.h" ]; then
  echo "PermissionStrategy.h not found in shared directory, creating it..."
  cat > "${SHARED_DIR}/PermissionStrategy.h" << 'EOL'
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
fi

if [ ! -f "${SHARED_DIR}/PermissionHandlerEnums.h" ]; then
  echo "PermissionHandlerEnums.h not found in shared directory, creating it..."
  cat > "${SHARED_DIR}/PermissionHandlerEnums.h" << 'EOL'
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
fi

# Now create a copy in the strategies directory itself to handle direct imports
echo "Creating local copies of header files in strategies directory..."
cp "${SHARED_DIR}/PermissionStrategy.h" "${STRATEGIES_DIR}/PermissionStrategy.h"
cp "${SHARED_DIR}/PermissionHandlerEnums.h" "${STRATEGIES_DIR}/PermissionHandlerEnums.h"

# Fix the imports in all strategy files to use local headers
echo "Updating imports in strategy files to use local headers..."
for header in "${STRATEGIES_DIR}"/*.h; do
  echo "Fixing imports in $header..."
  
  # Create a temporary file
  TEMP_FILE="${header}.temp"
  
  # Read the file line by line, replacing imports as needed
  while IFS= read -r line; do
    # Check if the line contains an import for the files we moved
    if [[ "$line" == *"../shared/PermissionStrategy.h"* ]]; then
      echo "#import \"PermissionStrategy.h\"" >> "$TEMP_FILE"
    elif [[ "$line" == *"../shared/PermissionHandlerEnums.h"* ]]; then
      echo "#import \"PermissionHandlerEnums.h\"" >> "$TEMP_FILE"
    else
      echo "$line" >> "$TEMP_FILE"
    fi
  done < "$header"
  
  # Replace the original file with our modified version
  mv "$TEMP_FILE" "$header"
done

# Fix the implementations in all strategy files
for impl in "${STRATEGIES_DIR}"/*.m; do
  echo "Fixing imports in $impl..."
  
  # Create a temporary file
  TEMP_FILE="${impl}.temp"
  
  # Read the file line by line, replacing imports as needed
  while IFS= read -r line; do
    # Check if the line contains an import for the files we moved
    if [[ "$line" == *"../shared/PermissionHandlerEnums.h"* ]]; then
      echo "#import \"PermissionHandlerEnums.h\"" >> "$TEMP_FILE"
    else
      echo "$line" >> "$TEMP_FILE"
    fi
  done < "$impl"
  
  # Replace the original file with our modified version
  mv "$TEMP_FILE" "$impl"
done

# Fix SensorPermissionStrategy.h to use local imports
echo "Fixing SensorPermissionStrategy.h..."
cat > "${STRATEGIES_DIR}/SensorPermissionStrategy.h" << 'EOL'
//
//  SensorPermissionStrategy.h
//  permission_handler
//
//  Created by Sebastian Roth on 5/21/20.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import "PermissionStrategy.h"

@interface SensorPermissionStrategy : NSObject <PermissionStrategy>
@end
EOL

# Fix SensorPermissionStrategy.m to use local imports
echo "Fixing SensorPermissionStrategy.m..."
cat > "${STRATEGIES_DIR}/SensorPermissionStrategy.m" << 'EOL'
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

echo "Header paths fixed. Now clean and rebuild the project in Xcode." 