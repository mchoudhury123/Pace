#!/bin/bash

# Simple script to fix the recursive app nesting issue

echo "=== FIXING RECURSIVE APP NESTING ISSUE ==="

# Clean build and DerivedData
echo "Cleaning build directories..."
rm -rf build
rm -rf ios/build
rm -rf ios/DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*Runner*

# Find and delete any nested Runner.app directories
echo "Removing nested app bundles..."
find . -name "*.app" -type d -path "*Runner.app/*Runner.app*" -exec rm -rf {} \; 2>/dev/null || true

# Create a script that uses direct xcodebuild
echo "Creating direct xcodebuild script..."
cat > xcode_direct_build.sh << 'EOF'
#!/bin/bash

# Clean build
rm -rf ios/build

# Set build flags to avoid nesting
export COPY_PHASE_STRIP=YES
export STRIP_INSTALLED_PRODUCT=YES
export APPLICATION_EXTENSION_API_ONLY=YES

cd ios
xcodebuild \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build/DerivedData \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  COPY_PHASE_STRIP=YES \
  STRIP_INSTALLED_PRODUCT=YES \
  APPLICATION_EXTENSION_API_ONLY=YES \
  build

echo "Direct Xcode build completed."
echo "You can find the built app at: ios/build/DerivedData/Build/Products/Release-iphoneos/Runner.app"
EOF

chmod +x xcode_direct_build.sh

echo "Nest fix complete!"
echo "Now run: ./xcode_direct_build.sh" 