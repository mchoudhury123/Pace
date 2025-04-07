#!/bin/bash

echo "Fixing LocationPermissionStrategy.m issues..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"
TARGET_FILE="${STRATEGY_DIR}/LocationPermissionStrategy.m"
HEADER_FILE="${STRATEGY_DIR}/LocationPermissionStrategy.h"

# Check if the files exist
if [ -f "$TARGET_FILE" ] && [ -f "$HEADER_FILE" ]; then
    # Create backup with timestamp to avoid overwriting existing backups
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    sudo cp "$TARGET_FILE" "${TARGET_FILE}.backup_${TIMESTAMP}"
    sudo cp "$HEADER_FILE" "${HEADER_FILE}.backup_${TIMESTAMP}"
    echo "Created backups with timestamp ${TIMESTAMP}"
    
    # Make sure we have write permissions
    sudo chmod +w "$TARGET_FILE" "$HEADER_FILE"
    
    # Fix the header file first
    sudo cat > "$HEADER_FILE" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

@interface LocationPermissionStrategy : NSObject<PermissionStrategy>

+ (CLAuthorizationStatus)CLAuthorizationStatusForPermission:(PermissionGroup)permission;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$TARGET_FILE" << 'EOL'
#import "LocationPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

#if PERMISSION_LOCATION

#import <CoreLocation/CoreLocation.h>

@interface LocationPermissionStrategy () <CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) PermissionStatusCallback permissionStatusHandler;
@property (strong, nonatomic) ServiceStatusCallback serviceStatusHandler;
@end

@implementation LocationPermissionStrategy

+ (CLAuthorizationStatus)CLAuthorizationStatusForPermission:(PermissionGroup)permission {
    if (@available(iOS 14.0, *)) {
        if (permission == PermissionGroupLocationWhenInUse) {
            return [CLLocationManager authorizationStatus];
        } else if (permission == PermissionGroupLocationAlways) {
            return [CLLocationManager authorizationStatus];
        }
    }
    
    return [CLLocationManager authorizationStatus];
}

- (instancetype)initWithLocationManager {
    self = [super init];
    if (self) {
        _locationManager = [CLLocationManager new];
        _locationManager.delegate = self;
    }
    
    return self;
}

- (instancetype)init {
    return [self initWithLocationManager];
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    CLAuthorizationStatus authorizationStatus = [LocationPermissionStrategy CLAuthorizationStatusForPermission:permission];

    PermissionStatus status;
    
    switch (authorizationStatus) {
        case kCLAuthorizationStatusNotDetermined:
            status = PermissionStatusUndetermined;
            break;
        case kCLAuthorizationStatusRestricted:
            status = PermissionStatusRestricted;
            break;
        case kCLAuthorizationStatusDenied:
            status = PermissionStatusDenied;
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            status = permission == PermissionGroupLocationAlways
                ? PermissionStatusDenied
                : PermissionStatusGranted;
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
            status = PermissionStatusGranted;
            break;
        default:
            status = PermissionStatusUndetermined;
            break;
    }
    
    return status;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    ServiceStatus status;
    
    // Directly creating CLLocationManager might cause crash if authorization not granted
    if ([CLLocationManager locationServicesEnabled]) {
        status = ServiceStatusEnabled;
    } else {
        status = ServiceStatusDisabled;
    }
    
    return status;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    self.permissionStatusHandler = completion;
    
    if (permission == PermissionGroupLocation) {
        permission = PermissionGroupLocationWhenInUse;
    }
    
    if (permission == PermissionGroupLocationAlways) {
        [self.locationManager requestAlwaysAuthorization];
    } else if (permission == PermissionGroupLocationWhenInUse) {
        [self.locationManager requestWhenInUseAuthorization];
    } else {
        if (completion) {
            completion(PermissionStatusUnknown);
        }
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (self.permissionStatusHandler) {
        self.permissionStatusHandler([self checkPermissionStatus:PermissionGroupLocationWhenInUse]);
        self.permissionStatusHandler = nil;
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (self.permissionStatusHandler) {
        self.permissionStatusHandler([self checkPermissionStatus:PermissionGroupLocationWhenInUse]);
        self.permissionStatusHandler = nil;
    }
}

@end

#else

@implementation LocationPermissionStrategy

+ (CLAuthorizationStatus)CLAuthorizationStatusForPermission:(PermissionGroup)permission {
    return 0;
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusUnsupported;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion(PermissionStatusUnsupported);
    }
}

@end

#endif
EOL
    
    # Make sure the file permissions are correct
    sudo chmod 644 "$TARGET_FILE" "$HEADER_FILE"
    
    echo "Fixed LocationPermissionStrategy files"
    echo "Header file contents:"
    cat "$HEADER_FILE"
else
    echo "Error: One or more required files not found!"
    [ ! -f "$TARGET_FILE" ] && echo "Missing: $TARGET_FILE"
    [ ! -f "$HEADER_FILE" ] && echo "Missing: $HEADER_FILE"
    exit 1
fi

echo "LocationPermissionStrategy fix completed!" 