#!/bin/bash

echo "Starting Error Codes fix for permission_handler_apple..."

# Set paths
PHONE_PERM_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6/ios/Classes/strategies/PhonePermissionStrategy.m"
ERROR_CODES_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6/ios/Classes/ErrorCodes.h"
PERMISSION_HANDLER_ENUMS="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6/ios/Classes/PermissionHandlerEnums.h"

# Check if file exists
if [ ! -f "$PHONE_PERM_PATH" ]; then
    echo "Error: PhonePermissionStrategy.m file not found at $PHONE_PERM_PATH"
    exit 1
fi

# Create ErrorCodes.h file if it doesn't exist
if [ ! -f "$ERROR_CODES_PATH" ]; then
    echo "Creating ErrorCodes.h file..."
    cat > "$ERROR_CODES_PATH" << 'EOF'
// ErrorCodes.h
#ifndef ErrorCodes_h
#define ErrorCodes_h

typedef NS_ENUM(NSUInteger, ErrorCode) {
    /// Request has been denied by the user
    PermissionStatusDenied = 0,
    /// Permission has been granted by the user
    PermissionStatusGranted = 1,
    /// Permission is restricted and can't be used
    PermissionStatusRestricted = 2,
    /// Permission has not yet been requested, and is in an undetermined state
    PermissionStatusUndetermined = 3,
    /// Permission cannot be determined, due to an error
    PermissionStatusUnknown = 4,
    /// Permission is still being determined
    PermissionStatusPermanentlyDenied = 5,
    /// Permission is limited in some way
    PermissionStatusLimited = 6,
    /// Permission for this feature was provisionally granted by the user
    PermissionStatusProvisional = 7,
};

#endif /* ErrorCodes_h */
EOF
    echo "ErrorCodes.h file created successfully."
fi

# Create a backup of the PhonePermissionStrategy.m file
cp "$PHONE_PERM_PATH" "${PHONE_PERM_PATH}.backup3"
echo "Created backup of PhonePermissionStrategy.m at ${PHONE_PERM_PATH}.backup3"

# Replace the PhonePermissionStrategy.m file with the fixed version
cat > "$PHONE_PERM_PATH" << 'EOF'
//
//  PhonePermissionStrategy.m
//  permission_handler
//
//  Created by Sebastian Röhl on 03/04/23.
//

#import "PhonePermissionStrategy.h"
#import "ErrorCodes.h"
#import "PermissionHandlerEnums.h"

@implementation PhonePermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
#if EXTENSION
    return PermissionStatusDenied;
#else
    if (@available(iOS 10, *)) {
        CTCellularProviderType type = CTCellularDataProviderGetTypeID();
        if (type == 0) {
            return PermissionStatusNotDetermined;
        }
    
        return [self getPermissionStatus];
    }
    
    return PermissionStatusNotDetermined;
#endif
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
#if EXTENSION
    return ServiceStatusNotApplicable;
#else
    if (@available(iOS 10, *)) {
        CTCellularProviderType type = CTCellularDataProviderGetTypeID();
        if (type == 0) {
            return ServiceStatusNotDetermined;
        }
        
        return [self getServiceStatus];
    }
    
    return ServiceStatusNotDetermined;
#endif
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusHandler)completionHandler {
#if EXTENSION
    completionHandler(PermissionStatusDenied);
#else
    if (@available(iOS 10, *)) {
        PermissionStatus permissionStatus = [self checkPermissionStatus:permission];
        if (permissionStatus != PermissionStatusDenied) {
            completionHandler(permissionStatus);
            return;
        }
        
        CTCellularData *cellularData = [[CTCellularData alloc] init];
        cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
            switch (state) {
                case kCTCellularDataRestricted:
                    completionHandler(PermissionStatusDenied);
                    break;
                case kCTCellularDataNotRestricted:
                    completionHandler(PermissionStatusGranted);
                    break;
                default:
                    completionHandler(PermissionStatusDenied);
                    break;
            }
        };
        
        // Load the status once to trigger the notifier
        CTCellularDataRestrictedState state = cellularData.restrictedState;
    } else {
        completionHandler(PermissionStatusNotDetermined);
    }
#endif
}

- (PermissionStatus)getPermissionStatus {
#if EXTENSION
    return PermissionStatusDenied;
#else
    CTCellularData *cellularData = [[CTCellularData alloc] init];
    CTCellularDataRestrictedState state = cellularData.restrictedState;
    
    switch (state) {
        case kCTCellularDataRestricted:
            return PermissionStatusDenied;
            break;
        case kCTCellularDataNotRestricted:
            return PermissionStatusGranted;
            break;
        default:
            return PermissionStatusNotDetermined;
            break;
    }
#endif
}

- (ServiceStatus)getServiceStatus {
#if EXTENSION
    return ServiceStatusNotApplicable;
#else
    if (@available(iOS 12, *)) {
        // On iOS 12, we can use the cellular provider to determine if there's a SIM card
        CTCellularData *cellularData = [[CTCellularData alloc] init];
        if (cellularData != nil) {
            return ServiceStatusEnabled;
        } else {
            return ServiceStatusDisabled;
        }
    } else {
        // For older iOS versions, assume service is available
        return ServiceStatusEnabled;
    }
#endif
}

@end
EOF

echo "PhonePermissionStrategy.m file updated successfully."

# Create the final build script
cat > "ios_final_build_with_error_codes_fix.sh" << 'EOF'
#!/bin/bash

# Clean and reinstall pods
cd ios
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
pod install

# Set environment variables
export EXTENSION=1
export NO_FLIPPER=1

# Build the app
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos \
  GCC_PREPROCESSOR_DEFINITIONS="$GCC_PREPROCESSOR_DEFINITIONS COCOAPODS=1 EXTENSION=1" \
  DEVELOPMENT_TEAM="3XDM85H9UV" clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
EOF

chmod +x ios_final_build_with_error_codes_fix.sh

echo "Error Codes fix completed. You can now run ./ios_final_build_with_error_codes_fix.sh to build the app." 