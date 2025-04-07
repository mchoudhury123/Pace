#!/bin/bash

echo "Fixing permission handler header conflicts..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGIES_DIR="${PLUGIN_PATH}/ios/Classes/strategies"

# First, let's move PermissionStrategy.h to the correct location
STRATEGY_HEADER="${PLUGIN_PATH}/ios/Classes/PermissionStrategy.h"
mkdir -p "${PLUGIN_PATH}/ios/Classes/strategies/utils"
UTILS_DIR="${PLUGIN_PATH}/ios/Classes/strategies/utils"

echo "Moving PermissionStrategy.h to avoid duplicate outputs..."
# Move the file to a utils subdirectory
cp "${STRATEGY_HEADER}" "${UTILS_DIR}/PermissionStrategy.h"
rm "${STRATEGY_HEADER}"

echo "Updating header imports in strategy files..."

# Update the import in SensorPermissionStrategy.h
SENSOR_HEADER="${STRATEGIES_DIR}/SensorPermissionStrategy.h"
cat > "${SENSOR_HEADER}" << 'EOL'
//
//  SensorPermissionStrategy.h
//  permission_handler
//
//  Created by Sebastian Roth on 5/21/20.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import "utils/PermissionStrategy.h"
#import "../PermissionHandlerEnums.h"

@interface SensorPermissionStrategy : NSObject <PermissionStrategy>
@end
EOL

# Update the import in PhonePermissionStrategy.h
PHONE_HEADER="${STRATEGIES_DIR}/PhonePermissionStrategy.h"
if [ -f "$PHONE_HEADER" ]; then
  echo "Updating PhonePermissionStrategy.h..."
  sed -i.bak 's/#import "..\/PermissionStrategy.h"/#import "utils\/PermissionStrategy.h"/' "${PHONE_HEADER}"
fi

# Update the import in BackgroundRefreshStrategy.h
BG_HEADER="${STRATEGIES_DIR}/BackgroundRefreshStrategy.h"
if [ -f "$BG_HEADER" ]; then
  echo "Updating BackgroundRefreshStrategy.h..."
  sed -i.bak 's/#import "..\/PermissionStrategy.h"/#import "utils\/PermissionStrategy.h"/' "${BG_HEADER}"
fi

# Update the permission handler plugin header
PLUGIN_HEADER="${PLUGIN_PATH}/ios/Classes/PermissionHandlerPlugin.h"
if [ -f "$PLUGIN_HEADER" ]; then
  echo "Updating PermissionHandlerPlugin.h..."
  sed -i.bak 's/#import "PermissionStrategy.h"/#import "strategies\/utils\/PermissionStrategy.h"/' "${PLUGIN_HEADER}"
fi

# Clean derived data to force a clean build
echo "Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

echo "Permission handler header conflicts fixed. Please clean and rebuild your project in Xcode."
echo "In Xcode, go to Product > Clean Build Folder and then rebuild." 