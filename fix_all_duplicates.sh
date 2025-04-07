#!/bin/bash

echo "Fixing all duplicate permission header conflicts..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGIES_DIR="${PLUGIN_PATH}/ios/Classes/strategies"
CLASSES_DIR="${PLUGIN_PATH}/ios/Classes"

# Clean up any previous fixes
echo "Cleaning up previous fixes..."
rm -rf "${CLASSES_DIR}/shared"

# Create a centralized "shared" directory for headers
mkdir -p "${CLASSES_DIR}/shared"
SHARED_DIR="${CLASSES_DIR}/shared"

# Get the original PermissionHandlerEnums.h and save it to the shared directory
echo "Creating unified PermissionHandlerEnums.h in shared directory..."
if [ -f "${CLASSES_DIR}/PermissionHandlerEnums.h" ]; then
  cp "${CLASSES_DIR}/PermissionHandlerEnums.h" "${SHARED_DIR}/PermissionHandlerEnums.h"
else
  # If it doesn't exist in the main dir, create it from scratch
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

# Create the unified PermissionStrategy.h in the shared directory
echo "Creating unified PermissionStrategy.h in shared directory..."
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

# Find and remove all instances of PermissionStrategy.h and PermissionHandlerEnums.h
echo "Removing all duplicate header files..."
find "${PLUGIN_PATH}" -path "${SHARED_DIR}" -prune -o -name "PermissionStrategy.h" -print -exec rm {} \;
find "${PLUGIN_PATH}" -path "${SHARED_DIR}" -prune -o -name "PermissionHandlerEnums.h" -print -exec rm {} \;

# Update all strategy header files to use the shared headers
echo "Updating all strategy headers..."
for header in "${STRATEGIES_DIR}"/*.h; do
  echo "Updating $header..."
  
  # Create a temporary file
  TEMP_FILE="${header}.temp"
  
  # Read the file line by line, replacing imports as needed
  while IFS= read -r line; do
    # Check if the line contains an import for the files we moved
    if [[ "$line" == *"PermissionStrategy.h"* ]]; then
      echo "#import \"../shared/PermissionStrategy.h\"" >> "$TEMP_FILE"
    elif [[ "$line" == *"PermissionHandlerEnums.h"* ]]; then
      echo "#import \"../shared/PermissionHandlerEnums.h\"" >> "$TEMP_FILE"
    else
      echo "$line" >> "$TEMP_FILE"
    fi
  done < "$header"
  
  # Replace the original file with our modified version
  mv "$TEMP_FILE" "$header"
done

# Update specific strategy files that need special attention
echo "Updating SensorPermissionStrategy.h..."
cat > "${STRATEGIES_DIR}/SensorPermissionStrategy.h" << 'EOL'
//
//  SensorPermissionStrategy.h
//  permission_handler
//
//  Created by Sebastian Roth on 5/21/20.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import "../shared/PermissionStrategy.h"

@interface SensorPermissionStrategy : NSObject <PermissionStrategy>
@end
EOL

echo "Updating SensorPermissionStrategy.m..."
cat > "${STRATEGIES_DIR}/SensorPermissionStrategy.m" << 'EOL'
//
//  SensorPermissionStrategy.m
//  permission_handler
//
//  Created by Sebastian Roth on 5/21/20.
//

#import "SensorPermissionStrategy.h"
#import "../shared/PermissionHandlerEnums.h"

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

# Update the main plugin header if it exists
if [ -f "${CLASSES_DIR}/PermissionHandlerPlugin.h" ]; then
  echo "Updating PermissionHandlerPlugin.h..."
  
  # Create a temporary file
  TEMP_FILE="${CLASSES_DIR}/PermissionHandlerPlugin.h.temp"
  
  # Read the file line by line, replacing imports as needed
  while IFS= read -r line; do
    # Check if the line contains an import for the files we moved
    if [[ "$line" == *"PermissionStrategy.h"* ]]; then
      echo "#import \"shared/PermissionStrategy.h\"" >> "$TEMP_FILE"
    elif [[ "$line" == *"PermissionHandlerEnums.h"* ]]; then
      echo "#import \"shared/PermissionHandlerEnums.h\"" >> "$TEMP_FILE"
    else
      echo "$line" >> "$TEMP_FILE"
    fi
  done < "${CLASSES_DIR}/PermissionHandlerPlugin.h"
  
  # Replace the original file with our modified version
  mv "$TEMP_FILE" "${CLASSES_DIR}/PermissionHandlerPlugin.h"
fi

# Update the module map file to include only the shared headers
echo "Creating module map file..."
mkdir -p "${PLUGIN_PATH}/ios/Classes"
cat > "${PLUGIN_PATH}/ios/Classes/module.modulemap" << 'EOL'
framework module permission_handler_apple {
  umbrella header "../permission_handler_apple.h"
  
  export *
  module * { export * }
}
EOL

# Create a single umbrella header
echo "Creating umbrella header..."
cat > "${PLUGIN_PATH}/ios/permission_handler_apple.h" << 'EOL'
#import <Foundation/Foundation.h>

//! Project version number for permission_handler.
FOUNDATION_EXPORT double permission_handlerVersionNumber;

//! Project version string for permission_handler.
FOUNDATION_EXPORT const unsigned char permission_handlerVersionString[];

#import "Classes/shared/PermissionHandlerEnums.h"
#import "Classes/shared/PermissionStrategy.h"
#import "Classes/PermissionHandlerPlugin.h"
EOL

# Clean up the build directory completely
echo "Cleaning up build directory..."
cd ~/fundracer_app_new/ios
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
cd ..
flutter clean

# Go back to iOS directory and reinstall pods
echo "Reinstalling pods..."
cd ios
pod install --repo-update

echo "All duplicate header conflicts fixed."
echo "Please follow these steps precisely:"
echo "1. Close Xcode completely"
echo "2. Run 'cd ~/fundracer_app_new && flutter clean'"
echo "3. Run 'cd ios && pod install --repo-update'"
echo "4. Open the workspace with 'open Runner.xcworkspace'"
echo "5. In Xcode, go to Product > Clean Build Folder"
echo "6. Build the app" 