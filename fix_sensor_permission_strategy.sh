#!/bin/bash

echo "Fixing SensorPermissionStrategy.m CoreMotion reference issues..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"
TARGET_FILE="${STRATEGY_DIR}/SensorPermissionStrategy.m"
HEADER_FILE="${STRATEGY_DIR}/SensorPermissionStrategy.h"

# Check if the files exist
if [ -f "$TARGET_FILE" ] && [ -f "$HEADER_FILE" ]; then
    # Create backup with timestamp to avoid overwriting existing backups
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    sudo cp "$TARGET_FILE" "${TARGET_FILE}.backup_${TIMESTAMP}"
    sudo cp "$HEADER_FILE" "${HEADER_FILE}.backup_${TIMESTAMP}"
    echo "Created backups with timestamp ${TIMESTAMP}"
    
    # Make sure we have write permissions
    sudo chmod +w "$TARGET_FILE" "$HEADER_FILE"
    
    # Fix the header file first - use forward declaration for CoreMotion types
    sudo cat > "$HEADER_FILE" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

// Forward declaration to avoid direct import of CoreMotion in header
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
@class CMMotionActivityManager;
typedef NS_ENUM(NSInteger, CMAuthorizationStatus) {
    CMAuthorizationStatusNotDetermined = 0,
    CMAuthorizationStatusRestricted,
    CMAuthorizationStatusDenied,
    CMAuthorizationStatusAuthorized
};
#endif

@interface SensorPermissionStrategy : NSObject<PermissionStrategy>

+ (PermissionStatus)permissionStatusForMotionManager;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$TARGET_FILE" << 'EOL'
#import "SensorPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

// Import CoreMotion only in implementation file
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
#import <CoreMotion/CoreMotion.h>
#endif

@implementation SensorPermissionStrategy

+ (PermissionStatus)permissionStatusForMotionManager {
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
    if (@available(iOS 11.0, *)) {
        CMAuthorizationStatus cmStatus = [CMMotionActivityManager authorizationStatus];
        
        switch (cmStatus) {
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

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return [SensorPermissionStrategy permissionStatusForMotionManager];
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
    if (@available(iOS 11.0, *)) {
        CMMotionActivityManager *motionManager = [[CMMotionActivityManager alloc] init];
        NSDate *today = [NSDate new];
        
        [motionManager queryActivityStartingFromDate:today
                                              toDate:today
                                             toQueue:[NSOperationQueue mainQueue]
                                         withHandler:^(NSArray * _Nullable activities, NSError * _Nullable error) {
            
            CMAuthorizationStatus cmStatus = [CMMotionActivityManager authorizationStatus];
            
            PermissionStatus permissionStatus;
            switch (cmStatus) {
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
        completion(PermissionStatusNotDetermined);
    }
#endif
}

@end
EOL
    
    # Make sure the file permissions are correct
    sudo chmod 644 "$TARGET_FILE" "$HEADER_FILE"
    
    echo "Fixed SensorPermissionStrategy files"
    echo "Implementation file contents:"
    cat "$TARGET_FILE"
    echo "Header file contents:"
    cat "$HEADER_FILE"
else
    echo "Error: One or more required files not found!"
    [ ! -f "$TARGET_FILE" ] && echo "Missing: $TARGET_FILE"
    [ ! -f "$HEADER_FILE" ] && echo "Missing: $HEADER_FILE"
    exit 1
fi

echo "SensorPermissionStrategy fix completed!" 