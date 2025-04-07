#!/bin/bash

echo "Fixing AppAuth extension compatibility issues..."

SOURCE_FILE="OIDExternalUserAgentIOSCustomBrowser.m.fixed"
TARGET_FILE="/Users/mohammedchoudhury/fundracer_app_new/ios/Pods/AppAuth/Sources/AppAuth/iOS/OIDExternalUserAgentIOSCustomBrowser.m"

# Check if the source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Fixed source file $SOURCE_FILE not found!"
    exit 1
fi

# Check if the target file exists
if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: Target file $TARGET_FILE not found!"
    exit 1
fi

# Create backup of the original file
echo "Creating backup of original file..."
sudo cp "$TARGET_FILE" "${TARGET_FILE}.backup"

# Copy the fixed file to the target location
echo "Copying fixed file to target location..."
sudo cp "$SOURCE_FILE" "$TARGET_FILE"

# Reset permissions
sudo chmod 644 "$TARGET_FILE"

echo "AppAuth extension compatibility fixes completed!" 