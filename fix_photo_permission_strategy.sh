#!/bin/bash

echo "Fixing PhotoPermissionStrategy.m issues..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"
TARGET_FILE="${STRATEGY_DIR}/PhotoPermissionStrategy.m"
HEADER_FILE="${STRATEGY_DIR}/PhotoPermissionStrategy.h"

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

@interface PhotoPermissionStrategy : NSObject<PermissionStrategy>

+ (PermissionStatus)permissionStatus;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$TARGET_FILE" << 'EOL'
#import "PhotoPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

#if PERMISSION_PHOTOS

#import <Photos/Photos.h>

@implementation PhotoPermissionStrategy

+ (PermissionStatus)permissionStatus {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    return [PhotoPermissionStrategy determinePermissionStatus:status];
}

+ (PermissionStatus)determinePermissionStatus:(PHAuthorizationStatus)authorizationStatus {
    switch (authorizationStatus) {
        case PHAuthorizationStatusNotDetermined:
            return PermissionStatusDenied;
        case PHAuthorizationStatusRestricted:
            return PermissionStatusRestricted;
        case PHAuthorizationStatusDenied:
            return PermissionStatusPermanentlyDenied;
        case PHAuthorizationStatusAuthorized:
            return PermissionStatusGranted;
        case PHAuthorizationStatusLimited:
            return PermissionStatusLimited;
    }
    
    return PermissionStatusDenied;
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return [PhotoPermissionStrategy permissionStatus];
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    if (permission == PermissionGroupPhotos) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus authorizationStatus) {
            PermissionStatus status = [PhotoPermissionStrategy determinePermissionStatus:authorizationStatus];
            
            if (completion) {
                completion(status);
            }
        }];
    } else if (permission == PermissionGroupPhotosAddOnly) {
        if (@available(iOS 14, *)) {
            [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                                        handler:^(PHAuthorizationStatus authorizationStatus) {
                PermissionStatus status = [PhotoPermissionStrategy determinePermissionStatus:authorizationStatus];
                
                if (completion) {
                    completion(status);
                }
            }];
        } else {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus authorizationStatus) {
                PermissionStatus status = [PhotoPermissionStrategy determinePermissionStatus:authorizationStatus];
                
                if (completion) {
                    completion(status);
                }
            }];
        }
    } else if (permission == PermissionGroupLimitedPhotos) {
        if (@available(iOS 14, *)) {
            [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                        handler:^(PHAuthorizationStatus authorizationStatus) {
                PermissionStatus status = [PhotoPermissionStrategy determinePermissionStatus:authorizationStatus];
                
                if (completion) {
                    completion(status);
                }
            }];
        } else {
            if (completion) {
                completion(PermissionStatusDenied);
            }
        }
    } else {
        if (completion) {
            completion(PermissionStatusDenied);
        }
    }
}

@end

#else

@implementation PhotoPermissionStrategy

+ (PermissionStatus)permissionStatus {
    return PermissionStatusUnsupported;
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
    
    echo "Fixed PhotoPermissionStrategy files"
    echo "Header file contents:"
    cat "$HEADER_FILE"
else
    echo "Error: One or more required files not found!"
    [ ! -f "$TARGET_FILE" ] && echo "Missing: $TARGET_FILE"
    [ ! -f "$HEADER_FILE" ] && echo "Missing: $HEADER_FILE"
    exit 1
fi

echo "PhotoPermissionStrategy fix completed!" 