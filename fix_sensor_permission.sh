#!/bin/bash

echo "Fixing SensorPermissionStrategy implementation..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_FILE="${PLUGIN_PATH}/ios/Classes/strategies/SensorPermissionStrategy.m"

# Create backup
echo "Creating backup of the original file..."
cp "${STRATEGY_FILE}" "${STRATEGY_FILE}.sensor_bak"

# Replace the file with a fixed implementation
echo "Updating the SensorPermissionStrategy implementation..."
cat > "${STRATEGY_FILE}" << 'EOL'
//
//  SensorPermissionStrategy.m
//  permission_handler
//
//  Created by Sebastian Roth on 5/21/20.
//

#import "SensorPermissionStrategy.h"

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

echo "SensorPermissionStrategy fix completed." 