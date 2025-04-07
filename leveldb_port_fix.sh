#!/bin/bash

echo "Starting LevelDB port fix..."

# Set paths
VERSION_SET_PATH="/Users/mohammedchoudhury/fundracer_app_new/ios/Pods/leveldb-library/db/version_set.h"
VERSION_SET_CC_PATH="/Users/mohammedchoudhury/fundracer_app_new/ios/Pods/leveldb-library/db/version_set.cc"
PORT_HEADER_PATH="/Users/mohammedchoudhury/fundracer_app_new/ios/Pods/leveldb-library/port/port.h"

# Check if files exist
if [ ! -f "$VERSION_SET_PATH" ]; then
    echo "Error: version_set.h file not found at $VERSION_SET_PATH"
    exit 1
fi

if [ ! -f "$VERSION_SET_CC_PATH" ]; then
    echo "Error: version_set.cc file not found at $VERSION_SET_CC_PATH"
    exit 1
fi

# Create backups of the files
cp "$VERSION_SET_PATH" "${VERSION_SET_PATH}.backup"
cp "$VERSION_SET_CC_PATH" "${VERSION_SET_CC_PATH}.backup"

echo "Created backups of version_set files."

# Fix the version_set.h file
sed -i "" 's/Status LogAndApply(VersionEdit\* edit, port::Mutex\* mu)/Status LogAndApply(VersionEdit* edit, void* mu)/g' "$VERSION_SET_PATH"

# Fix the version_set.cc file
sed -i "" 's/Status VersionSet::LogAndApply(VersionEdit\* edit, port::Mutex\* mu) {/Status VersionSet::LogAndApply(VersionEdit* edit, void* mu) {/g' "$VERSION_SET_CC_PATH"

echo "Fixed port::Mutex references in version_set files."

# Now exclude leveldb-library from the build
cat > "xcconfig_leveldb_fix.sh" << 'EOF'
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
EOF

chmod +x xcconfig_leveldb_fix.sh
./xcconfig_leveldb_fix.sh

echo "LevelDB port fix completed. You can now run ./ios_final_build_with_leveldb_fix.sh to build the app." 