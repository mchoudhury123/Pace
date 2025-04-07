#!/bin/bash

echo "Fixing StoragePermissionStrategy.m syntax errors..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"
TARGET_FILE="${STRATEGY_DIR}/StoragePermissionStrategy.m"
HEADER_FILE="${STRATEGY_DIR}/StoragePermissionStrategy.h"

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

@interface StoragePermissionStrategy : NSObject<PermissionStrategy>

+ (PermissionStatus)permissionStatus;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$TARGET_FILE" << 'EOL'
#import "StoragePermissionStrategy.h"
#import "PermissionHandlerEnums.h"

@implementation StoragePermissionStrategy

+ (PermissionStatus)permissionStatus {
    return PermissionStatusGranted;
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return [StoragePermissionStrategy permissionStatus];
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion([StoragePermissionStrategy permissionStatus]);
    }
}

@end
EOL
    
    # Make sure the file permissions are correct
    sudo chmod 644 "$TARGET_FILE" "$HEADER_FILE"
    
    echo "Fixed StoragePermissionStrategy files"
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

echo "StoragePermissionStrategy fix completed!" 