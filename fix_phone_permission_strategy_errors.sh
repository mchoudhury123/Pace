#!/bin/bash

echo "Starting PhonePermissionStrategy error fixes..."

# Set paths
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
PHONE_STRATEGY_PATH="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/PhonePermissionStrategy.m"

# Create a fresh backup of the original file (just in case)
if [ -f "${PHONE_STRATEGY_PATH}" ]; then
    cp "${PHONE_STRATEGY_PATH}" "${PHONE_STRATEGY_PATH}.original"
    echo "Created backup at ${PHONE_STRATEGY_PATH}.original"
    
    # Replace the file with a correct implementation
    cat > "${PHONE_STRATEGY_PATH}" << 'EOL'
//
//  PhonePermissionStrategy.m
//  permission_handler
//
#import <CoreTelephony/CTCellularData.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "PhonePermissionStrategy.h"

@implementation PhonePermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
#ifdef EXTENSION
    return PermissionStatusDenied;
#else
    if (@available(iOS 12, *)) {
        CTCellularData *cellularData = [[CTCellularData alloc] init];
        
        if (cellularData.restrictedState == kCTCellularDataRestrictedStateUnknown) {
            return PermissionStatusUnknown;
        } else if (cellularData.restrictedState == kCTCellularDataRestricted) {
            return PermissionStatusDenied;
        } else if (cellularData.restrictedState == kCTCellularDataNotRestricted) {
            return PermissionStatusGranted;
        }
    }
    
    return PermissionStatusUnknown;
#endif
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
#ifdef EXTENSION
    if (completion) {
        completion(PermissionStatusDenied);
    }
#else
    if (@available(iOS 12, *)) {
        CTCellularData *cellularData = [[CTCellularData alloc] init];
        
        __weak CTCellularData *weakCellularData = cellularData;
        cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state) {
            if (completion) {
                if (state == kCTCellularDataRestricted) {
                    completion(PermissionStatusDenied);
                } else if (state == kCTCellularDataNotRestricted) {
                    completion(PermissionStatusGranted);
                } else {
                    completion(PermissionStatusUnknown);
                }
                
                // Cleanup to avoid retain cycles
                weakCellularData.cellularDataRestrictionDidUpdateNotifier = nil;
            }
        };
        
        // Check current status
        CTCellularDataRestrictedState state = cellularData.restrictedState;
        if (state != kCTCellularDataRestrictedStateUnknown) {
            if (state == kCTCellularDataRestricted) {
                completion(PermissionStatusDenied);
            } else if (state == kCTCellularDataNotRestricted) {
                completion(PermissionStatusGranted);
            } else {
                completion(PermissionStatusUnknown);
            }
            cellularData.cellularDataRestrictionDidUpdateNotifier = nil;
        }
    } else {
        if (completion) {
            completion(PermissionStatusUnknown);
        }
    }
#endif
}

@end
EOL
    
    echo "Updated PhonePermissionStrategy.m with correct implementation"
else
    echo "ERROR: PhonePermissionStrategy.m not found at ${PHONE_STRATEGY_PATH}"
fi

# Remove ErrorCodes.h reference if it's included
if grep -q "#import \"ErrorCodes.h\"" "${PHONE_STRATEGY_PATH}"; then
    echo "Removing ErrorCodes.h import"
    sed -i '' '/#import "ErrorCodes.h"/d' "${PHONE_STRATEGY_PATH}"
fi

echo "PhonePermissionStrategy error fixes completed." 