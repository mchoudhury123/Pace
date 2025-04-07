#!/bin/bash

echo "Fixing framework linking issues (CoreMotion and CoreLocation)..."

# Path to iOS directory
IOS_DIR="ios"
PODFILE_PATH="${IOS_DIR}/Podfile"

# Backup Podfile
if [ -f "$PODFILE_PATH" ]; then
    cp "$PODFILE_PATH" "${PODFILE_PATH}.frameworks.backup"
    echo "Created backup at ${PODFILE_PATH}.frameworks.backup"
    
    # Modify the post_install hook to add framework linking
    awk '
    /post_install do \|installer\|/ {
        print $0
        inside_post_install = 1
        next
    }
    
    /target.build_configurations.each do \|config\|/ && inside_post_install {
        print $0
        print "      # Add CoreMotion and CoreLocation frameworks"
        print "      config.build_settings['\''OTHER_LDFLAGS'\''] ||= []"
        print "      if config.build_settings['\''OTHER_LDFLAGS'\''].is_a?(Array)"
        print "        config.build_settings['\''OTHER_LDFLAGS'\''] << '\''-framework'\''"
        print "        config.build_settings['\''OTHER_LDFLAGS'\''] << '\''CoreMotion'\''"
        print "        config.build_settings['\''OTHER_LDFLAGS'\''] << '\''-framework'\''"
        print "        config.build_settings['\''OTHER_LDFLAGS'\''] << '\''CoreLocation'\''"
        print "      end"
        next
    }
    
    { print $0 }
    ' "${PODFILE_PATH}.frameworks.backup" > "${PODFILE_PATH}"
    
    echo "Modified ${PODFILE_PATH} to include CoreMotion and CoreLocation frameworks"
else
    echo "Error: ${PODFILE_PATH} not found!"
    exit 1
fi

# Update the SensorPermissionStrategy to handle CoreMotion import properly
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
SENSOR_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/SensorPermissionStrategy.h"
SENSOR_STRATEGY_M="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/SensorPermissionStrategy.m"

# Update the header file to use forward declaration instead of import
if [ -f "$SENSOR_STRATEGY_H" ]; then
    cp "$SENSOR_STRATEGY_H" "${SENSOR_STRATEGY_H}.backup"
    
    cat > "$SENSOR_STRATEGY_H" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

// Forward declare CMAuthorizationStatus to avoid header import
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
typedef enum {
    CMAuthorizationStatusNotDetermined = 0,
    CMAuthorizationStatusRestricted,
    CMAuthorizationStatusDenied,
    CMAuthorizationStatusAuthorized
} CMAuthorizationStatus;
#endif

@interface SensorPermissionStrategy : NSObject<PermissionStrategy>

@end
EOL
    
    echo "Updated SensorPermissionStrategy.h with forward declaration"
fi

# Update the implementation file to import CoreMotion
if [ -f "$SENSOR_STRATEGY_M" ]; then
    cp "$SENSOR_STRATEGY_M" "${SENSOR_STRATEGY_M}.backup"
    
    cat > "$SENSOR_STRATEGY_M" << 'EOL'
#import "SensorPermissionStrategy.h"

#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
#import <CoreMotion/CoreMotion.h>
#endif

@implementation SensorPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
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
    
    return PermissionStatusDenied;
#else
    return PermissionStatusNotDetermined;
#endif
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusHandler)completion {
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
    if (@available(iOS 11.0, *)) {
        CMMotionActivityManager *motionManager = [[CMMotionActivityManager alloc] init];
        NSDate *today = [NSDate new];
        
        [motionManager queryActivityStartingFromDate:today
                                              toDate:today
                                             toQueue:[NSOperationQueue mainQueue]
                                         withHandler:^(NSArray<CMMotionActivity *> * _Nullable activities, NSError * _Nullable error) {
            
            CMAuthorizationStatus status = [CMMotionActivityManager authorizationStatus];
            
            PermissionStatus permissionStatus;
            switch (status) {
                case CMAuthorizationStatusNotDetermined:
                    permissionStatus = PermissionStatusDenied;
                    break;
                case CMAuthorizationStatusRestricted:
                    permissionStatus = PermissionStatusRestricted;
                    break;
                case CMAuthorizationStatusDenied:
                    permissionStatus = PermissionStatusDenied;
                    break;
                case CMAuthorizationStatusAuthorized:
                    permissionStatus = PermissionStatusGranted;
                    break;
                default:
                    permissionStatus = PermissionStatusDenied;
                    break;
            }
            
            if (completion) {
                completion(permissionStatus);
            }
        }];
    } else {
        if (completion) {
            completion(PermissionStatusDenied);
        }
    }
#else
    if (completion) {
        completion(PermissionStatusDenied);
    }
#endif
}

@end
EOL
    
    echo "Updated SensorPermissionStrategy.m with proper CoreMotion import"
fi

echo "Framework linking fix completed!" 