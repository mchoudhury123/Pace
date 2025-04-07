#!/bin/bash

echo "Applying all iOS fixes after reset..."

cd ios

# Check if we need to reapply AppAuth fix
APPAUTH_FILE="Pods/AppAuth/Sources/AppAuth/iOS/OIDExternalUserAgentIOSCustomBrowser.m"
if [ -f "$APPAUTH_FILE" ]; then
    echo "Applying AppAuth extension compatibility fix..."
    # Create backup
    sudo cp "$APPAUTH_FILE" "${APPAUTH_FILE}.backup"
    
    # Copy our fixed version
    sudo cp "../OIDExternalUserAgentIOSCustomBrowser.m.fixed" "$APPAUTH_FILE"
    
    # Reset permissions
    sudo chmod 644 "$APPAUTH_FILE"
    
    echo "AppAuth fix applied"
fi

# Navigate back to project root
cd ..

# Now let's open the project
echo "Opening Xcode workspace..."
open ios/Runner.xcworkspace

echo "All fixes applied. Please build the project in Xcode now."
echo "If the 'PIF transfer session' error persists, try the following steps:"
echo "1. Close Xcode"
echo "2. Run: sudo rm -rf ~/Library/Developer/Xcode/DerivedData"
echo "3. Run: sudo xcode-select --reset"
echo "4. Open Xcode again with: open ios/Runner.xcworkspace"
echo "5. In Xcode menu, choose Product > Clean Build Folder (Shift+Cmd+K)"
echo "6. Build the project again" 