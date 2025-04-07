#!/bin/bash

echo "Fixing PhotoPermissionStrategy.m for limited photos..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"
TARGET_FILE="${STRATEGY_DIR}/PhotoPermissionStrategy.m"
ENUMS_FILE="${PERMISSION_HANDLER_PATH}/ios/Classes/PermissionHandlerEnums.h"

# Check if the files exist
if [ -f "$TARGET_FILE" ] && [ -f "$ENUMS_FILE" ]; then
    # Create backup with timestamp to avoid overwriting existing backups
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    sudo cp "$TARGET_FILE" "${TARGET_FILE}.backup_${TIMESTAMP}"
    sudo cp "$ENUMS_FILE" "${ENUMS_FILE}.backup_${TIMESTAMP}"
    echo "Created backups with timestamp ${TIMESTAMP}"
    
    # Make sure we have write permissions
    sudo chmod +w "$TARGET_FILE" "$ENUMS_FILE"
    
    # First check and fix the enum definition
    if ! grep -q "PermissionGroupLimitedPhotos" "$ENUMS_FILE"; then
        echo "Adding PermissionGroupLimitedPhotos to PermissionHandlerEnums.h"
        # Find the PermissionGroup enum and add LimitedPhotos if not present
        sudo awk 'BEGIN{fixed=0}
        /typedef NS_ENUM.*PermissionGroup/ {print; inEnum=1; next}
        inEnum && !fixed && /PermissionGroupPhotosAddOnly/ {print; print "    PermissionGroupLimitedPhotos,"; fixed=1; next}
        inEnum && /};/ {inEnum=0}
        {print}' "$ENUMS_FILE" > temp_enums.h
        sudo mv temp_enums.h "$ENUMS_FILE"
    else
        echo "PermissionGroupLimitedPhotos already exists in PermissionHandlerEnums.h"
    fi
    
    # Now fix the PhotoPermissionStrategy.m implementation
    echo "Updating PhotoPermissionStrategy.m to handle limited photos properly"
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
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
        case PHAuthorizationStatusLimited:
            return PermissionStatusLimited;
#endif
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
    } else if (permission == 25) { // Use a direct number instead of PermissionGroupLimitedPhotos to avoid enum issues
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
    sudo chmod 644 "$TARGET_FILE" "$ENUMS_FILE"
    
    echo "Fixed PhotoPermissionStrategy.m for limited photos"
    echo "Enums file content related to PermissionGroupLimitedPhotos:"
    grep -A 30 "typedef NS_ENUM" "$ENUMS_FILE" | grep -B 30 PermissionGroupCount
else
    echo "Error: One or more required files not found!"
    [ ! -f "$TARGET_FILE" ] && echo "Missing: $TARGET_FILE"
    [ ! -f "$ENUMS_FILE" ] && echo "Missing: $ENUMS_FILE"
    exit 1
fi

echo "PhotoPermissionStrategy fix for limited photos completed!" 