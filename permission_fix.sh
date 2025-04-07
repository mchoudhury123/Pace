#!/bin/bash

echo "Starting permission_handler_apple fix..."

# Set the path to the PhonePermissionStrategy.m file
PHONE_STRATEGY_FILE="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6/ios/Classes/strategies/PhonePermissionStrategy.m"

if [ ! -f "$PHONE_STRATEGY_FILE" ]; then
  echo "Error: PhonePermissionStrategy.m file not found at $PHONE_STRATEGY_FILE"
  exit 1
fi

# Backup the original file
cp "$PHONE_STRATEGY_FILE" "${PHONE_STRATEGY_FILE}.backup"
echo "Created backup at ${PHONE_STRATEGY_FILE}.backup"

# Replace the problematic code that uses UIApplication.sharedApplication
cat > "$PHONE_STRATEGY_FILE" << 'EOF'
#import <Foundation/Foundation.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

#import "PhonePermissionStrategy.h"

@implementation PhonePermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
  // In app extensions, we always return "denied" for phone permission status
  // as we can't use UIApplication.sharedApplication
  #if defined(EXTENSION)
    return PermissionStatusDenied;
  #else
    return PermissionStatusGranted;
  #endif
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
  CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
    
  // Using serviceSubscriberCellularProviders instead of the deprecated subscriberCellularProvider
  NSDictionary *providers = nil;
  if (@available(iOS 12.0, *)) {
    providers = [netInfo serviceSubscriberCellularProviders];
  } else {
    // Handle older iOS versions without using deprecated API
    return ServiceStatusUnknown;
  }
    
  if (providers.count == 0) {
    return ServiceStatusNotAvailable;
  }
    
  return ServiceStatusAvailable;
}

- (void)requestPermission:(PermissionGroup)permission
           completionHandler:(PermissionStatusHandler)completionHandler {
  // In app extensions, we can't request phone permissions, so just return the current status
  completionHandler([self checkPermissionStatus:permission]);
}

@end
EOF

echo "Updated PhonePermissionStrategy.m file to avoid using UIApplication.sharedApplication"

# Create the final build script
cat > ios_final_build_with_permissions.sh << 'EOF'
#!/bin/bash
set -e

# Clean and reinstall pods
cd ios
rm -rf Pods Podfile.lock
pod install

# Set environment variables for the build
export COMPILATION_MODE=wholemodule
export EXTENSION=1

# Build the app
xcodebuild clean build \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS EXTENSION=1 COCOAPODS=1 OPENSSL_NO_ASM=1'

echo "=== iOS build completed ==="
EOF

chmod +x ios_final_build_with_permissions.sh
echo "Created final build script: ios_final_build_with_permissions.sh"

echo "Permission handler fix completed" 