#!/bin/bash

# Create a custom .xcconfig file to exclude leveldb files from the build
cat > exclude_leveldb.xcconfig << 'XCCONFIG'
// Exclude leveldb files causing issues
OTHER_LDFLAGS = $(inherited) -framework FirebaseFirestore
PODS_BUILD_DIR = ${BUILD_DIR}
PODS_CONFIGURATION_BUILD_DIR = ${PODS_BUILD_DIR}/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)
EXCLUDED_SOURCE_FILE_NAMES = version_set.cc version_edit.cc table_builder.cc
XCCONFIG

echo "Custom xcconfig created to exclude problematic leveldb files."

# Create final build script that uses the custom xcconfig
cat > "ios_final_build_with_leveldb_fix.sh" << 'SCRIPT'
#!/bin/bash

# Clean and reinstall pods
cd ios
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
pod install

# Set environment variables
export EXTENSION=1
export NO_FLIPPER=1

# Build the app with custom xcconfig
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos \
  GCC_PREPROCESSOR_DEFINITIONS="$GCC_PREPROCESSOR_DEFINITIONS COCOAPODS=1 EXTENSION=1" \
  DEVELOPMENT_TEAM="3XDM85H9UV" -xcconfig ../exclude_leveldb.xcconfig \
  clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
SCRIPT

chmod +x ios_final_build_with_leveldb_fix.sh
echo "Created final build script with LevelDB fix."
