#!/bin/bash

echo "Fixing SpeechPermissionStrategy.m with correct permission status enums..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"
TARGET_FILE="${STRATEGY_DIR}/SpeechPermissionStrategy.m"

# Check if the file exists
if [ -f "$TARGET_FILE" ]; then
    # Create backup with timestamp
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    sudo cp "$TARGET_FILE" "${TARGET_FILE}.backup_${TIMESTAMP}"
    echo "Created backup with timestamp ${TIMESTAMP}"
    
    # Make sure we have write permissions
    sudo chmod +w "$TARGET_FILE"
    
    # Read the file and replace PermissionStatusUnsupported with PermissionStatusRestricted
    sudo sed -i'.bak' 's/PermissionStatusUnsupported/PermissionStatusRestricted/g' "$TARGET_FILE"
    
    # Make sure the file permissions are correct
    sudo chmod 644 "$TARGET_FILE"
    
    echo "Fixed SpeechPermissionStrategy.m with correct permission status enums"
else
    echo "Error: SpeechPermissionStrategy.m not found at $TARGET_FILE"
    exit 1
fi

echo "SpeechPermissionStrategy fix completed!" 