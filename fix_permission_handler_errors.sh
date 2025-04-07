#!/bin/bash

echo "Starting permission_handler_apple fixes..."

# Set paths
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"

# Fix PhonePermissionStrategy.m
echo "Fixing PhonePermissionStrategy.m..."
PHONE_STRATEGY="${STRATEGY_DIR}/PhonePermissionStrategy.m"
if [ -f "$PHONE_STRATEGY" ]; then
    # Create backup
    cp "$PHONE_STRATEGY" "${PHONE_STRATEGY}.final_backup"
    
    # Remove ErrorCodes.h import and fix the file
    cat > "$PHONE_STRATEGY" << 'EOF'
//
//  PhonePermissionStrategy.m
//  permission_handler
//

#import "PhonePermissionStrategy.h"
#import <CoreTelephony/CTCellularData.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

@implementation PhonePermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
#if TARGET_OS_OSX
    return PermissionStatusPermanentlyDenied;
#else
    if (@available(iOS 12, *)) {
        CTCellularData *cellularData = [[CTCellularData alloc] init];
        
        switch (cellularData.restrictedState) {
            case kCTCellularDataRestricted:
                return PermissionStatusDenied;
            case kCTCellularDataNotRestricted:
                return PermissionStatusGranted;
            default:
                return PermissionStatusDenied;
        }
    }
    
    return PermissionStatusDenied;
#endif
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
#if TARGET_OS_OSX
    if (completion) {
        completion(PermissionStatusPermanentlyDenied);
    }
#else
    if (@available(iOS 12, *)) {
        PermissionStatus status = [self checkPermissionStatus:permission];
        
        if (completion) {
            completion(status);
        }
    } else {
        if (completion) {
            completion(PermissionStatusDenied);
        }
    }
#endif
}

@end
EOF
    
    echo "Fixed PhonePermissionStrategy.m"
else
    echo "Error: PhonePermissionStrategy.m not found!"
    exit 1
fi

# Fix BackgroundRefreshStrategy.m
echo "Fixing BackgroundRefreshStrategy.m..."
BACKGROUND_STRATEGY="${STRATEGY_DIR}/BackgroundRefreshStrategy.m"
if [ -f "$BACKGROUND_STRATEGY" ]; then
    # Create backup
    cp "$BACKGROUND_STRATEGY" "${BACKGROUND_STRATEGY}.final_backup"
    
    # Replace with fixed implementation
    cat > "$BACKGROUND_STRATEGY" << 'EOF'
//
//  BackgroundRefreshStrategy.m
//  permission_handler
//

#import "BackgroundRefreshStrategy.h"

@implementation BackgroundRefreshStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
#if TARGET_OS_OSX
    return PermissionStatusPermanentlyDenied;
#else
    if (@available(iOS 13, *)) {
        UIBackgroundRefreshStatus status = [[UIApplication sharedApplication] backgroundRefreshStatus];
        
        switch(status) {
            case UIBackgroundRefreshStatusAvailable:
                return PermissionStatusGranted;
            case UIBackgroundRefreshStatusDenied:
                return PermissionStatusDenied;
            case UIBackgroundRefreshStatusRestricted:
                return PermissionStatusRestricted;
            default:
                return PermissionStatusDenied;
        }
    }
    
    return PermissionStatusDenied;
#endif
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
#if TARGET_OS_OSX
    if (completion) {
        completion(PermissionStatusPermanentlyDenied);
    }
#else
    if (@available(iOS 13, *)) {
        PermissionStatus status = [self checkPermissionStatus:permission];
        
        if (completion) {
            completion(status);
        }
    } else {
        if (completion) {
            completion(PermissionStatusDenied);
        }
    }
#endif
}

@end
EOF
    
    echo "Fixed BackgroundRefreshStrategy.m"
else
    echo "Error: BackgroundRefreshStrategy.m not found!"
    exit 1
fi

# Fix SensorPermissionStrategy.m
echo "Fixing SensorPermissionStrategy.m..."
SENSOR_STRATEGY="${STRATEGY_DIR}/SensorPermissionStrategy.m"
if [ -f "$SENSOR_STRATEGY" ]; then
    # Create backup
    cp "$SENSOR_STRATEGY" "${SENSOR_STRATEGY}.final_backup"
    
    # Replace with fixed implementation
    cat > "$SENSOR_STRATEGY" << 'EOF'
//
//  SensorPermissionStrategy.m
//  permission_handler
//

#import "SensorPermissionStrategy.h"
#import <CoreMotion/CoreMotion.h>

@implementation SensorPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
#if TARGET_OS_OSX
    return PermissionStatusPermanentlyDenied;
#else
    if (@available(iOS 11.0, *)) {
        CMAuthorizationStatus status = [CMMotionActivityManager authorizationStatus];
        
        switch (status) {
            case CMAuthorizationStatusAuthorized:
                return PermissionStatusGranted;
            case CMAuthorizationStatusDenied:
                return PermissionStatusDenied;
            case CMAuthorizationStatusRestricted:
                return PermissionStatusRestricted;
            case CMAuthorizationStatusNotDetermined:
                return PermissionStatusDenied;
        }
    }
    
    return PermissionStatusDenied;
#endif
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
#if TARGET_OS_OSX
    if (completion) {
        completion(PermissionStatusPermanentlyDenied);
    }
#else
    if (@available(iOS 11.0, *)) {
        PermissionStatus status = [self checkPermissionStatus:permission];
        
        if (completion) {
            completion(status);
        }
    } else {
        if (completion) {
            completion(PermissionStatusDenied);
        }
    }
#endif
}

@end
EOF
    
    echo "Fixed SensorPermissionStrategy.m"
else
    echo "Error: SensorPermissionStrategy.m not found!"
    exit 1
fi

echo "permission_handler_apple fixes completed." 