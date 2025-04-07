#!/bin/bash

echo "Starting final build with device targeting fix..."

cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

# Create a backup of the Podfile
cp Podfile Podfile.backup

# Modify the Podfile to include post_install hooks that resolve common issues
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
  # Break circular dependencies
  installer.pods_project.targets.each do |target|
    if target.name == 'FirebaseCoreInternal-FirebaseCoreInternal_Privacy'
      target.build_configurations.each do |config|
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
      end
    end
  end
  
  # Fix build errors due to missing or incorrect architectures
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      config.build_settings["EXCLUDED_ARCHS[sdk=iphoneos*]"] = "i386 x86_64 armv7 armv7s armv6"
      
      # Set Swift versions correctly
      if config.build_settings['SWIFT_VERSION'] == '5.0'
        config.build_settings['SWIFT_VERSION'] = '5.0'
      end
    end
  end
  
  # Fix the CoreTelephony and ErrorCodes issues for permission_handler
  installer.pods_project.targets.each do |target|
    if target.name == 'permission_handler_apple'
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'PERMISSION_PHONE=1'
        
        # Fix framework search paths if needed
        config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
        config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(SDKROOT)/System/Library/Frameworks'
      end
    end
  end
  
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
EOL

echo "Modified Podfile with fixes for provisioning and circular dependencies"

pod install --repo-update

cd ..

# Build the app for generic device instead of a specific one
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' build

echo "Final build with device targeting fix completed." 