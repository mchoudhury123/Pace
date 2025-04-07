#!/bin/bash

echo "Creating missing PermissionStrategy.h file..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_HEADER="${PLUGIN_PATH}/ios/Classes/PermissionStrategy.h"
CLASSES_DIR="${PLUGIN_PATH}/ios/Classes"

# Make sure the Classes directory exists
if [ ! -d "$CLASSES_DIR" ]; then
  echo "Creating Classes directory..."
  mkdir -p "$CLASSES_DIR"
fi

# Create PermissionStrategy.h file
echo "Creating PermissionStrategy.h..."
cat > "${STRATEGY_HEADER}" << 'EOL'
//
//  PermissionStrategy.h
//  permission_handler
//
//  Created by Razvan Lung on 15/02/2019.
//

#import <Foundation/Foundation.h>
#import "PermissionHandlerEnums.h"

@protocol PermissionStrategy <NSObject>

- (void)requestPermission:(PermissionGroup)permission completion:(PermissionStatusCallback)completion;
- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission;
- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission;

@end
EOL

echo "PermissionStrategy.h created successfully."

# Also fix the SensorPermissionStrategy.h file to import PermissionStrategy.h
SENSOR_HEADER="${PLUGIN_PATH}/ios/Classes/strategies/SensorPermissionStrategy.h"
echo "Updating SensorPermissionStrategy.h to import PermissionStrategy.h..."
cat > "${SENSOR_HEADER}" << 'EOL'
//
//  SensorPermissionStrategy.h
//  permission_handler
//
//  Created by Sebastian Roth on 5/21/20.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import "../PermissionStrategy.h"
#import "../PermissionHandlerEnums.h"

@interface SensorPermissionStrategy : NSObject <PermissionStrategy>
@end
EOL

echo "SensorPermissionStrategy.h updated successfully."

echo "Permission strategy headers fixed. Please rebuild your iOS project now." 