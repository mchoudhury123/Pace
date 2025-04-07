#!/bin/bash

echo "Fixing duplicate permission header conflicts..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGIES_DIR="${PLUGIN_PATH}/ios/Classes/strategies"
CLASSES_DIR="${PLUGIN_PATH}/ios/Classes"

# Create a centralized "shared" directory for headers
mkdir -p "${CLASSES_DIR}/shared"
SHARED_DIR="${CLASSES_DIR}/shared"

# First, ensure PermissionHandlerEnums.h is in the shared directory
echo "Moving PermissionHandlerEnums.h to shared directory..."
cp "${CLASSES_DIR}/PermissionHandlerEnums.h" "${SHARED_DIR}/PermissionHandlerEnums.h"

# Create the PermissionStrategy.h in the shared directory
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

# Find and remove all other instances of PermissionStrategy.h
echo "Removing duplicate PermissionStrategy.h files..."
find "${PLUGIN_PATH}" -path "${SHARED_DIR}/PermissionStrategy.h" -prune -o -name "PermissionStrategy.h" -print -exec rm {} \;

# Update SensorPermissionStrategy.h to use the shared header
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

# Update SensorPermissionStrategy.m to use the shared header
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

# Update PhonePermissionStrategy.h if it exists
if [ -f "${STRATEGIES_DIR}/PhonePermissionStrategy.h" ]; then
  echo "Updating PhonePermissionStrategy.h..."
  sed -i.bak 's/#import "..\/PermissionStrategy.h"/#import "..\/shared\/PermissionStrategy.h"/' "${STRATEGIES_DIR}/PhonePermissionStrategy.h"
  sed -i.bak 's/#import "PermissionStrategy.h"/#import "..\/shared\/PermissionStrategy.h"/' "${STRATEGIES_DIR}/PhonePermissionStrategy.h"
fi

# Update BackgroundRefreshStrategy.h if it exists
if [ -f "${STRATEGIES_DIR}/BackgroundRefreshStrategy.h" ]; then
  echo "Updating BackgroundRefreshStrategy.h..."
  sed -i.bak 's/#import "..\/PermissionStrategy.h"/#import "..\/shared\/PermissionStrategy.h"/' "${STRATEGIES_DIR}/BackgroundRefreshStrategy.h"
  sed -i.bak 's/#import "PermissionStrategy.h"/#import "..\/shared\/PermissionStrategy.h"/' "${STRATEGIES_DIR}/BackgroundRefreshStrategy.h"
fi

# Update all other strategy headers to use the shared header
for header in "${STRATEGIES_DIR}"/*.h; do
  if [[ "$header" != *SensorPermissionStrategy.h ]] && [[ "$header" != *PhonePermissionStrategy.h ]] && [[ "$header" != *BackgroundRefreshStrategy.h ]]; then
    echo "Updating $header..."
    sed -i.bak 's/#import "..\/PermissionStrategy.h"/#import "..\/shared\/PermissionStrategy.h"/' "$header"
    sed -i.bak 's/#import "PermissionStrategy.h"/#import "..\/shared\/PermissionStrategy.h"/' "$header"
  fi
done

# Update the permission handler plugin header
if [ -f "${CLASSES_DIR}/PermissionHandlerPlugin.h" ]; then
  echo "Updating PermissionHandlerPlugin.h..."
  sed -i.bak 's/#import "PermissionStrategy.h"/#import "shared\/PermissionStrategy.h"/' "${CLASSES_DIR}/PermissionHandlerPlugin.h"
  sed -i.bak 's/#import "strategies\/utils\/PermissionStrategy.h"/#import "shared\/PermissionStrategy.h"/' "${CLASSES_DIR}/PermissionHandlerPlugin.h"
  sed -i.bak 's/#import "strategies\/PermissionStrategy.h"/#import "shared\/PermissionStrategy.h"/' "${CLASSES_DIR}/PermissionHandlerPlugin.h"
fi

# Create a new umbrella header to expose the shared headers
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

# Clean derived data to force a clean build
echo "Cleaning build directory..."
cd ~/fundracer_app_new/ios
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

# Run pod install to recreate the pods
echo "Reinstalling pods..."
pod install

echo "Header conflicts fixed."
echo "Please clean and rebuild your project in Xcode:"
echo "1. In Xcode, go to Product > Clean Build Folder"
echo "2. Close Xcode and reopen it"
echo "3. Build again" 