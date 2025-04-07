#!/bin/bash

echo "Starting PhonePermissionStrategy fix..."

# Set the path to the permission_handler_apple plugin and specific files
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
PHONE_PERM_PATH="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/PhonePermissionStrategy.m"

# Check if the file exists
if [ ! -f "$PHONE_PERM_PATH" ]; then
    echo "Error: PhonePermissionStrategy.m file not found at ${PHONE_PERM_PATH}"
    exit 1
fi

# Create a backup of the file
cp "${PHONE_PERM_PATH}" "${PHONE_PERM_PATH}.backup4"
echo "Created backup of PhonePermissionStrategy.m at ${PHONE_PERM_PATH}.backup4"

# Replace the file content with a fixed version
cat > "${PHONE_PERM_PATH}" << 'EOL'
//
//  PhonePermissionStrategy.m
//  permission_handler
//
//  Created by Sebastian Röhl on 03/04/23.
//

#import "PhonePermissionStrategy.h"
#import "ErrorCodes.h"
#import "PermissionHandlerEnums.h"
#import <CoreTelephony/CTCellularData.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

@implementation PhonePermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
#if EXTENSION
    return PermissionStatusDenied;
#else
    if (@available(iOS 10, *)) {
        CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
        
        if (netInfo == nil) {
            return PermissionStatusDenied;
        }
        
        CTCellularData *cellularData = [[CTCellularData alloc] init];
        if (cellularData == nil) {
            return PermissionStatusDenied;
        }
        
        return PermissionStatusGranted;
    } else {
        return PermissionStatusUnknown;
    }
#endif
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
#if EXTENSION
    completion(PermissionStatusDenied);
#else
    if (@available(iOS 10, *)) {
        CTCellularData *cellularData = [[CTCellularData alloc] init];
        
        // Save the current restriction status
        CTCellularDataRestrictedState initialState = cellularData.restrictedState;
        
        // Force interaction with cellular data settings by monitoring restricted state changes
        cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
            if (state == kCTCellularDataRestricted) {
                completion(PermissionStatusDenied);
            } else if (state == kCTCellularDataNotRestricted) {
                completion(PermissionStatusGranted);
            } else {
                completion(PermissionStatusUnknown);
            }
            
            // Clean up by removing the callback
            cellularData.cellularDataRestrictionDidUpdateNotifier = nil;
        };
        
        // If the status doesn't change, return the current status
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (cellularData.cellularDataRestrictionDidUpdateNotifier != nil) {
                if (initialState == kCTCellularDataRestricted) {
                    completion(PermissionStatusDenied);
                } else if (initialState == kCTCellularDataNotRestricted) {
                    completion(PermissionStatusGranted);
                } else {
                    completion(PermissionStatusUnknown);
                }
                
                // Clean up by removing the callback
                cellularData.cellularDataRestrictionDidUpdateNotifier = nil;
            }
        });
    } else {
        completion(PermissionStatusUnknown);
    }
#endif
}

@end
EOL

echo "Updated PhonePermissionStrategy.m with fixed implementation"

# Create a final build script
cat > "ios_final_build_with_phone_fix.sh" << 'EOL'
#!/bin/bash

cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

pod install --repo-update

cd ..

export EXCLUDED_ARCHS="i386 armv7 armv7s armv6 x86_64"
export ARCHS="arm64"

xcodebuild -quiet -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release
EOL

chmod +x ios_final_build_with_phone_fix.sh

echo "Phone permission strategy fix completed. Run ./ios_final_build_with_phone_fix.sh to build the app." 