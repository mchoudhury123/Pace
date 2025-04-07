#!/bin/bash

echo "Starting iOS build for physical device..."

# Apply all necessary plugin fixes
echo "Applying flutter web auth fix..."
chmod +x fix_flutter_web_auth.sh
./fix_flutter_web_auth.sh

echo "Applying permission handler fixes..."
chmod +x fix_permission_handler_errors.sh
./fix_permission_handler_errors.sh

# Clean iOS build artifacts
echo "Cleaning iOS project..."
cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

# Install pods
echo "Installing pods..."
pod install --repo-update

echo "Build ready for opening in Xcode!"
echo ""
echo "To deploy to your physical device:"
echo "1. Open the workspace in Xcode: open Runner.xcworkspace"
echo "2. Select your device from the device dropdown in Xcode"
echo "3. Go to the 'Signing & Capabilities' tab"
echo "4. Check 'Automatically manage signing'"
echo "5. Select your team"
echo "6. Click the Run button to build and deploy to your device"
echo ""
echo "Alternatively, you can use the following command with your developer team ID:"
echo "xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -destination 'platform=iOS,id=DEVICE_ID_HERE' -allowProvisioningUpdates -developmentTeam YOUR_TEAM_ID clean build" 