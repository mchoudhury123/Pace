#!/bin/bash

echo "Fixing all permission strategy files with PermissionStatusUnsupported issues..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"

# Find all .m files in the strategies directory
STRATEGY_FILES=$(find "$STRATEGY_DIR" -name "*.m")

# Check if we found any files
if [ -z "$STRATEGY_FILES" ]; then
    echo "No strategy files found in $STRATEGY_DIR"
    exit 1
fi

# Create a backup directory with timestamp
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/backups_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

echo "Created backup directory: $BACKUP_DIR"

# Process each file
for FILE in $STRATEGY_FILES; do
    FILENAME=$(basename "$FILE")
    echo "Processing $FILENAME..."
    
    # Create backup
    cp "$FILE" "$BACKUP_DIR/$FILENAME"
    
    # Make sure we have write permissions
    sudo chmod +w "$FILE"
    
    # Replace PermissionStatusUnsupported with PermissionStatusRestricted
    # Use grep to check if the file contains the text we want to replace
    if grep -q "PermissionStatusUnsupported" "$FILE"; then
        sudo sed -i'.bak' 's/PermissionStatusUnsupported/PermissionStatusRestricted/g' "$FILE"
        echo "  Fixed PermissionStatusUnsupported in $FILENAME"
    else
        echo "  No PermissionStatusUnsupported found in $FILENAME"
    fi
    
    # Fix permission status enums if they reference undeclared identifiers
    if grep -q "PermissionStatusUnknown" "$FILE"; then
        sudo sed -i'.bak' 's/PermissionStatusUnknown/PermissionStatusDenied/g' "$FILE"
        echo "  Fixed PermissionStatusUnknown in $FILENAME"
    fi
    
    # Check for PermissionStatusUndetermined, which may be undefined
    if grep -q "PermissionStatusUndetermined" "$FILE" && ! grep -q "PermissionStatusUndetermined.*;" "$PERMISSION_HANDLER_PATH/ios/Classes/PermissionHandlerEnums.h"; then
        # Replace with the default enum (usually PermissionStatusDenied)
        sudo sed -i'.bak' 's/PermissionStatusUndetermined/PermissionStatusDenied/g' "$FILE"
        echo "  Fixed PermissionStatusUndetermined in $FILENAME"
    fi
    
    # Make sure file permissions are correct
    sudo chmod 644 "$FILE"
done

echo "All permission strategy files have been processed"

# Set paths
PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGIES_PATH="${PLUGIN_PATH}/ios/Classes/strategies"
BACKGROUND_REFRESH_PATH="${STRATEGIES_PATH}/BackgroundRefreshStrategy.m"
PHONE_PERM_PATH="${STRATEGIES_PATH}/PhonePermissionStrategy.m"
ERROR_CODES_PATH="${PLUGIN_PATH}/ios/Classes/ErrorCodes.h"
PERMISSION_HANDLER_ENUMS="${PLUGIN_PATH}/ios/Classes/PermissionHandlerEnums.h"

# Check if files exist
if [ ! -f "$BACKGROUND_REFRESH_PATH" ]; then
  echo "Error: BackgroundRefreshStrategy.m not found at $BACKGROUND_REFRESH_PATH"
  exit 1
fi

# Create backup of the BackgroundRefreshStrategy.m file
cp "$BACKGROUND_REFRESH_PATH" "${BACKGROUND_REFRESH_PATH}.backup"
echo "Created backup of BackgroundRefreshStrategy.m at ${BACKGROUND_REFRESH_PATH}.backup"

# Fix BackgroundRefreshStrategy.m
cat > "$BACKGROUND_REFRESH_PATH" << 'EOF'
//
//  BackgroundRefreshStrategy.m
//  permission_handler
//

#import "BackgroundRefreshStrategy.h"
#import "PermissionHandlerEnums.h"

@implementation BackgroundRefreshStrategy

+ (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    // Check if background refresh is enabled at the system level - only available for apps, not extensions
    #if !defined(TARGET_OS_APP_EXTENSION) || TARGET_OS_APP_EXTENSION == 0
        UIBackgroundRefreshStatus status = [UIApplication performSelector:@selector(sharedApplication)].backgroundRefreshStatus;
        
        switch (status) {
            case UIBackgroundRefreshStatusAvailable:
                return PermissionStatusGranted;
            case UIBackgroundRefreshStatusDenied:
                return PermissionStatusDenied;
            case UIBackgroundRefreshStatusRestricted:
                return PermissionStatusRestricted;
            default:
                return PermissionStatusUnknown;
        }
    #else
        // App extensions don't have access to background refresh
        return PermissionStatusRestricted;
    #endif
}

+ (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

+ (void)requestPermission:(PermissionGroup)permission completionHandler:(PermissionStatusHandler)completionHandler {
    PermissionStatus status = [BackgroundRefreshStrategy checkPermissionStatus:permission];
    completionHandler(status);
}

@end
EOF

echo "Fixed BackgroundRefreshStrategy.m to safely handle UIApplication.sharedApplication"

# Fix any other permission strategy files that use UIApplication.sharedApplication
for file in "${STRATEGIES_PATH}"/*.m; do
  # Skip files we've already fixed and backups
  if [[ "$file" == "$BACKGROUND_REFRESH_PATH" || "$file" == "$PHONE_PERM_PATH" || "$file" == *".backup"* ]]; then
    continue
  fi
  
  # Check if file uses UIApplication.sharedApplication
  if grep -q "UIApplication.sharedApplication" "$file"; then
    # Create backup
    cp "$file" "${file}.backup"
    echo "Created backup of $(basename "$file") at ${file}.backup"
    
    # Replace UIApplication.sharedApplication with safer version
    sed -i '' 's/UIApplication.sharedApplication/\[UIApplication performSelector:@selector(sharedApplication)\]/g' "$file"
    echo "Fixed $(basename "$file") to safely handle UIApplication.sharedApplication"
  fi
done

# Create a final build script
cat > ios_final_build_with_all_fixes.sh << 'EOF'
#!/bin/bash

echo "Starting final build with all fixes applied..."
cd ios

# Clean and reinstall pods
echo "Cleaning and reinstalling CocoaPods..."
pod deintegrate
rm -rf Pods Podfile.lock
pod install

# Set environment variables
export EXCLUDED_ARCHS="i386 armv7"

# Run the build command with excluded archs
echo "Building iOS app..."
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -allowProvisioningUpdates build

echo "iOS build completed."
EOF

# Make the build script executable
chmod +x ios_final_build_with_all_fixes.sh

echo "All permission strategy fixes completed. Run ./ios_final_build_with_all_fixes.sh to build the app." 