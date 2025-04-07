#!/bin/bash

echo "Fixing Podfile integration issues..."

cd ios/

# Create or update the xcconfig files to include the Pods configuration
echo "Updating Flutter configuration files..."

# Debug.xcconfig
cat > Flutter/Debug.xcconfig << EOL
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER=com.mfchoudhury.fundracerapp
EOL

# Release.xcconfig
cat > Flutter/Release.xcconfig << EOL
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER=com.mfchoudhury.fundracerapp
EOL

# Profile.xcconfig
cat > Flutter/Profile.xcconfig << EOL
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER=com.mfchoudhury.fundracerapp
EOL

# Remove output files that might be causing issues
echo "Cleaning problematic CocoaPods integration files..."
rm -f Pods/Target\ Support\ Files/Pods-Runner/Pods-Runner-frameworks-Release-input-files.xcfilelist
rm -f Pods/Target\ Support\ Files/Pods-Runner/Pods-Runner-frameworks-Release-output-files.xcfilelist
rm -f Pods/Target\ Support\ Files/Pods-Runner/Pods-Runner-resources-Release-input-files.xcfilelist
rm -f Pods/Target\ Support\ Files/Pods-Runner/Pods-Runner-resources-Release-output-files.xcfilelist

# Create empty files to prevent errors
touch Pods/Target\ Support\ Files/Pods-Runner/Pods-Runner-frameworks-Release-input-files.xcfilelist
touch Pods/Target\ Support\ Files/Pods-Runner/Pods-Runner-frameworks-Release-output-files.xcfilelist
touch Pods/Target\ Support\ Files/Pods-Runner/Pods-Runner-resources-Release-input-files.xcfilelist
touch Pods/Target\ Support\ Files/Pods-Runner/Pods-Runner-resources-Release-output-files.xcfilelist

echo "Reinstalling pods..."
pod install --repo-update

echo "✅ Podfile integration fixes complete!"
echo "Now you can run 'open Runner.xcworkspace' and build the app from Xcode." 