#!/bin/bash

echo "Fixing duplicate headers through podspec modification..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
PODSPEC_PATH="${PLUGIN_PATH}/ios/permission_handler_apple.podspec"

# Backup the original podspec
echo "Backing up original podspec..."
cp "${PODSPEC_PATH}" "${PODSPEC_PATH}.bak"

# Read the current podspec content
PODSPEC_CONTENT=$(cat "${PODSPEC_PATH}")

# Create a new podspec with modified header settings
echo "Modifying podspec to specify public headers..."
cat > "${PODSPEC_PATH}" << EOL
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'permission_handler_apple'
  s.version          = '9.3.0'
  s.summary          = 'Permission plugin for Flutter.'
  s.description      = <<-DESC
Permission plugin for Flutter. This plugin provides a cross-platform (iOS, Android) API to request and check permissions.
                       DESC
  s.homepage         = 'https://github.com/baseflow/flutter-permission-handler'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Baseflow' => 'hello@baseflow.com' }
  s.source           = { :http => 'https://github.com/baseflow/flutter-permission-handler/tree/master/' }
  s.source_files = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/PermissionHandlerEnums.h', 'Classes/PermissionStrategy.h'
  s.private_header_files = 'Classes/strategies/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  
  # Specify framework header structure
  s.header_mappings_dir = 'Classes'
  
  # Disable bitcode to avoid issues
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64',
    'ENABLE_BITCODE' => 'NO'
  }

  s.swift_version = '5.0'
end
EOL

echo "Podspec modified successfully."

# Clean up build artifacts
echo "Cleaning build artifacts..."
cd ~/fundracer_app_new/ios
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
cd ..
flutter clean

# Regenerate Flutter configs
echo "Running flutter pub get to regenerate configs..."
flutter pub get

# Reinstall pods with the modified podspec
echo "Reinstalling pods with the modified podspec..."
cd ios
pod install --repo-update

echo "Pod installation complete. Now try building your project in Xcode."
echo "IMPORTANT: Clear all Xcode caches before rebuilding:"
echo "1. Quit Xcode completely"
echo "2. In Terminal run: rm -rf ~/Library/Developer/Xcode/DerivedData/*"
echo "3. Open Xcode and go to Product > Clean Build Folder"
echo "4. Build the project" 