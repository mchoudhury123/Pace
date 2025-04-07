#!/bin/bash

echo "Fixing BackgroundRefreshStrategy.m with correct permission status enums..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"
TARGET_FILE="${STRATEGY_DIR}/BackgroundRefreshStrategy.m"
HEADER_FILE="${STRATEGY_DIR}/BackgroundRefreshStrategy.h"

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

@interface BackgroundRefreshStrategy : NSObject<PermissionStrategy>

+ (BOOL)isAppExtension;
+ (UIApplication *)safeSharedApplication;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$TARGET_FILE" << 'EOL'
#import "BackgroundRefreshStrategy.h"
#import "PermissionHandlerEnums.h"

#import <UIKit/UIKit.h>

@implementation BackgroundRefreshStrategy

+ (BOOL)isAppExtension {
    return [NSBundle.mainBundle.bundlePath hasSuffix:@".appex"];
}

+ (UIApplication *)safeSharedApplication {
    if ([self isAppExtension]) {
        return nil;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication];
#pragma clang diagnostic pop
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    if ([BackgroundRefreshStrategy isAppExtension]) {
        // App extensions can't access background refresh status
        return PermissionStatusDenied;
    }
    
    UIApplication *application = [BackgroundRefreshStrategy safeSharedApplication];
    if (!application) {
        return PermissionStatusDenied;
    }
    
    UIBackgroundRefreshStatus status = [application backgroundRefreshStatus];
    
    switch (status) {
        case UIBackgroundRefreshStatusAvailable:
            return PermissionStatusGranted;
        case UIBackgroundRefreshStatusDenied:
            return PermissionStatusDenied;
        case UIBackgroundRefreshStatusRestricted:
            return PermissionStatusRestricted;
    }
    
    return PermissionStatusDenied;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion([self checkPermissionStatus:permission]);
    }
}

@end
EOL
    
    # Make sure the file permissions are correct
    sudo chmod 644 "$TARGET_FILE" "$HEADER_FILE"
    
    echo "Fixed BackgroundRefreshStrategy files with correct permission status enums"
    echo "Header file contents:"
    cat "$HEADER_FILE"
else
    echo "Error: One or more required files not found!"
    [ ! -f "$TARGET_FILE" ] && echo "Missing: $TARGET_FILE"
    [ ! -f "$HEADER_FILE" ] && echo "Missing: $HEADER_FILE"
    exit 1
fi

echo "BackgroundRefreshStrategy fix completed!" 