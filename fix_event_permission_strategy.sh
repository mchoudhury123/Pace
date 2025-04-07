#!/bin/bash

echo "Fixing EventPermissionStrategy.h issues..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"
TARGET_FILE="${STRATEGY_DIR}/EventPermissionStrategy.m"
HEADER_FILE="${STRATEGY_DIR}/EventPermissionStrategy.h"

# Check if the files exist
if [ -f "$HEADER_FILE" ]; then
    # Create backup with timestamp to avoid overwriting existing backups
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    sudo cp "$HEADER_FILE" "${HEADER_FILE}.backup_${TIMESTAMP}"
    if [ -f "$TARGET_FILE" ]; then
        sudo cp "$TARGET_FILE" "${TARGET_FILE}.backup_${TIMESTAMP}"
    fi
    echo "Created backups with timestamp ${TIMESTAMP}"
    
    # Make sure we have write permissions
    sudo chmod +w "$HEADER_FILE"
    
    # Fix the header file first
    sudo cat > "$HEADER_FILE" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

@interface EventPermissionStrategy : NSObject<PermissionStrategy>

@end
EOL
    
    # Fix the implementation file if it exists
    if [ -f "$TARGET_FILE" ]; then
        sudo chmod +w "$TARGET_FILE"
        sudo cat > "$TARGET_FILE" << 'EOL'
#import "EventPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

#if PERMISSION_EVENTS

#import <EventKit/EventKit.h>

@implementation EventPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    
    switch (status) {
        case EKAuthorizationStatusNotDetermined:
            return PermissionStatusUndetermined;
        case EKAuthorizationStatusRestricted:
            return PermissionStatusRestricted;
        case EKAuthorizationStatusDenied:
            return PermissionStatusDenied;
        case EKAuthorizationStatusAuthorized:
            return PermissionStatusGranted;
    }
    
    return PermissionStatusUndetermined;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    EKEventStore *eventStore = [[EKEventStore alloc] init];
    
    [eventStore requestAccessToEntityType:EKEntityTypeEvent
                               completion:^(BOOL granted, NSError *error) {
        PermissionStatus permissionStatus = granted ? PermissionStatusGranted : PermissionStatusDenied;
        
        if (completion) {
            completion(permissionStatus);
        }
    }];
}

@end

#else

@implementation EventPermissionStrategy

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
    else
        # Create the implementation file if it doesn't exist
        sudo touch "$TARGET_FILE"
        sudo chmod +w "$TARGET_FILE"
        sudo cat > "$TARGET_FILE" << 'EOL'
#import "EventPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

@implementation EventPermissionStrategy

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
EOL
    fi
    
    # Make sure the file permissions are correct
    sudo chmod 644 "$HEADER_FILE"
    if [ -f "$TARGET_FILE" ]; then
        sudo chmod 644 "$TARGET_FILE"
    fi
    
    echo "Fixed EventPermissionStrategy files"
    echo "Header file contents:"
    cat "$HEADER_FILE"
else
    echo "Error: Header file not found: $HEADER_FILE"
    exit 1
fi

echo "EventPermissionStrategy fix completed!" 