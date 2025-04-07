#!/bin/bash

echo "Starting iOS rebuild with all permission fixes..."

# Set executable permissions on fix scripts
echo "Setting up fix scripts..."
chmod +x fix_flutter_web_auth.sh
chmod +x fix_web_auth_extension_safe.sh
chmod +x fix_background_refresh_strategy.sh
chmod +x fix_permission_handler_errors.sh
chmod +x fix_sensor_permission.sh
chmod +x fix_sensor_permission_header.sh
chmod +x fix_podfile_integration.sh

# Execute fixes
echo "Applying web auth fixes..."
./fix_flutter_web_auth.sh
./fix_web_auth_extension_safe.sh

echo "Applying sensor permission fixes..."
./fix_sensor_permission.sh
./fix_sensor_permission_header.sh

echo "Applying background refresh strategy fix..."
./fix_background_refresh_strategy.sh

echo "Applying permission handler fixes..."
./fix_permission_handler_errors.sh

# Clean up iOS folder
echo "Cleaning iOS build environment..."
cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

# Fix Podfile
echo "Fixing Podfile integration..."
cd ..
./fix_podfile_integration.sh

echo "Opening Xcode workspace..."
cd ios
open Runner.xcworkspace

echo "iOS build prepared with all fixes. Please build directly from Xcode now." 