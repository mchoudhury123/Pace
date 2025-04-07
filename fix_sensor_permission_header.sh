#!/bin/bash

echo "Fixing SensorPermissionStrategy header file..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
HEADER_FILE="${PLUGIN_PATH}/ios/Classes/strategies/SensorPermissionStrategy.h"

# Create backup
echo "Creating backup of the original header file..."
cp "${HEADER_FILE}" "${HEADER_FILE}.header_bak"

# Replace the file with a fixed implementation
echo "Updating the SensorPermissionStrategy header..."
cat > "${HEADER_FILE}" << 'EOL'
//
//  SensorPermissionStrategy.h
//  permission_handler
//
//  Created by Sebastian Roth on 5/21/20.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

#import "PermissionStrategy.h"
#import "PermissionHandlerEnums.h"

@interface SensorPermissionStrategy : NSObject <PermissionStrategy>
@end
EOL

echo "SensorPermissionStrategy header fix completed." 