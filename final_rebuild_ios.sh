#!/bin/bash

echo "Starting final iOS rebuild with all fixes applied..."

# Set executable permissions on fix scripts
echo "Setting up fix scripts..."
chmod +x fix_flutter_web_auth.sh
chmod +x fix_web_auth_extension_safe.sh
chmod +x fix_background_refresh_strategy.sh
chmod +x fix_permission_handler_errors.sh
chmod +x fix_sensor_permission.sh
chmod +x fix_sensor_permission_header.sh
chmod +x fix_permission_handler_types.sh
chmod +x fix_permission_strategy_header.sh
chmod +x fix_podfile_integration.sh

# Execute fixes in the correct order
echo "Applying web auth fixes..."
./fix_flutter_web_auth.sh
./fix_web_auth_extension_safe.sh

echo "Applying permission handler fixes..."
./fix_permission_handler_types.sh
./fix_permission_strategy_header.sh
./fix_sensor_permission.sh
./fix_sensor_permission_header.sh
./fix_background_refresh_strategy.sh
./fix_permission_handler_errors.sh

# Clean up iOS folder completely
echo "Cleaning iOS build environment..."
cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Fix Podfile
echo "Creating optimized Podfile..."
cat > Podfile << 'EOL'
# Uncomment this line to define a global platform for your project
platform :ios, '14.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # This is important to avoid linking issues
  pod 'CoreMotion'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Start of the permission handler fix
    target.build_configurations.each do |config|
      # You can enable the permissions needed here. For example to enable camera
      # permission, just remove the `#` character in front so it looks like this:
      #
      # ## dart: PermissionGroup.camera
      # 'PERMISSION_CAMERA=1',
      #
      #  Preprocessor definitions can be found in: https://github.com/Baseflow/flutter-permission-handler/blob/master/permission_handler_apple/ios/Classes/PermissionHandlerEnums.h
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',

        ## dart: PermissionGroup.calendar
        # 'PERMISSION_EVENTS=1',

        ## dart: PermissionGroup.reminders
        # 'PERMISSION_REMINDERS=1',

        ## dart: PermissionGroup.contacts
        # 'PERMISSION_CONTACTS=1',

        ## dart: PermissionGroup.camera
        'PERMISSION_CAMERA=1',

        ## dart: PermissionGroup.microphone
        'PERMISSION_MICROPHONE=1',

        ## dart: PermissionGroup.speech
        # 'PERMISSION_SPEECH_RECOGNIZER=1',

        ## dart: PermissionGroup.photos
        'PERMISSION_PHOTOS=1',

        ## dart: PermissionGroup.location
        'PERMISSION_LOCATION=1',

        ## dart: PermissionGroup.notification
        'PERMISSION_NOTIFICATIONS=1',

        ## dart: PermissionGroup.mediaLibrary
        'PERMISSION_MEDIA_LIBRARY=1',

        ## dart: PermissionGroup.sensors
        'PERMISSION_SENSORS=1',

        ## dart: PermissionGroup.bluetooth
        # 'PERMISSION_BLUETOOTH=1',

        ## dart: PermissionGroup.appTrackingTransparency
        # 'PERMISSION_APP_TRACKING_TRANSPARENCY=1',

        ## dart: PermissionGroup.criticalAlerts
        # 'PERMISSION_CRITICAL_ALERTS=1',

        ## dart: PermissionGroup.backgroundRefresh
        'PERMISSION_BACKGROUND_REFRESH=1',
      ]
    end
    
    # Fix Xcode 14+ compatibility issues
    target.build_configurations.each do |config|
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
      config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
      config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      
      # Set application extension API only to YES
      config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      
      # Add arm64 architecture to valid architectures
      config.build_settings['VALID_ARCHS'] = 'arm64 arm64e'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386 arm64'
    end
  end
end
EOL

# Set environment variables to exclude legacy architectures
export EXCLUDED_ARCHS="i386 armv7"

# Install pods
echo "Installing pods..."
pod install --repo-update

# Fix CocoaPods integration
echo "Fixing Podfile integration..."
cd ..
./fix_podfile_integration.sh

# Now, let's make sure the xcconfig files include proper settings
cd ios
echo "Updating Flutter configuration files..."

# Update Flutter-Debug.xcconfig
cat > Flutter/Debug.xcconfig << 'EOL'
#include "Generated.xcconfig"
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
EOL

# Update Flutter-Release.xcconfig
cat > Flutter/Release.xcconfig << 'EOL'
#include "Generated.xcconfig"
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
EOL

# Update Flutter-Profile.xcconfig
cat > Flutter/Profile.xcconfig << 'EOL'
#include "Generated.xcconfig"
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"
EOL

# Open Xcode workspace
echo "Opening Xcode workspace..."
open Runner.xcworkspace

echo "Final iOS build prepared with all fixes applied."
echo "Please build directly from Xcode now." 