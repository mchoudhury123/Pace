#!/bin/bash

echo "Starting iOS final build with all fixes..."

# Set executable permissions on fix scripts
echo "Setting up fix scripts..."
chmod +x fix_flutter_web_auth.sh
chmod +x fix_background_refresh_strategy.sh
chmod +x fix_permission_handler_errors.sh
chmod +x fix_web_auth_extension_safe.sh
chmod +x fix_unknown_permission_strategy.sh
chmod +x fix_frameworks.sh
chmod +x fix_appauth_extension.sh

# Execute fixes
echo "Applying flutter_web_auth_2 fixes..."
./fix_flutter_web_auth.sh

echo "Applying web_auth extension-safe fix..."
./fix_web_auth_extension_safe.sh

echo "Applying background refresh strategy fix..."
./fix_background_refresh_strategy.sh

echo "Applying permission handler fixes..."
./fix_permission_handler_errors.sh

echo "Applying UnknownPermissionStrategy fix..."
./fix_unknown_permission_strategy.sh

echo "Applying framework linking fixes..."
./fix_frameworks.sh

# Clean up iOS folder
echo "Cleaning iOS build environment..."
cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Backup old Podfile if it exists
if [ -f "Podfile" ]; then
  echo "Backing up existing Podfile..."
  cp Podfile Podfile.backup
fi

# Create optimized Podfile
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

        ## dart: [PermissionGroup.location, PermissionGroup.locationAlways, PermissionGroup.locationWhenInUse]
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
      
      # Add CoreMotion and CoreLocation frameworks
      config.build_settings['OTHER_LDFLAGS'] ||= []
      if config.build_settings['OTHER_LDFLAGS'].is_a?(Array)
        config.build_settings['OTHER_LDFLAGS'] << '-framework'
        config.build_settings['OTHER_LDFLAGS'] << 'CoreMotion'
        config.build_settings['OTHER_LDFLAGS'] << '-framework'
        config.build_settings['OTHER_LDFLAGS'] << 'CoreLocation'
      end
    end
  end
end
EOL

# Set environment variables to exclude legacy architectures
export EXCLUDED_ARCHS="i386 armv7"

# Install pods
echo "Installing pods..."
pod install --repo-update

# Apply AppAuth fix after pods are installed
echo "Applying AppAuth extension compatibility fix..."
cd ..
./fix_appauth_extension.sh

# Run the additional Podfile integration fix
echo "Applying Podfile integration fixes..."
chmod +x fix_podfile_integration.sh
./fix_podfile_integration.sh

# Open Xcode workspace
echo "Opening Xcode workspace..."
cd ios
open Runner.xcworkspace

echo "iOS build prepared. Please build directly from Xcode now." 