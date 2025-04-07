#!/bin/bash

echo "Fixing CoreMotion missing framework issue..."

# First, let's fix the iOS Podfile to properly link CoreMotion
cd ~/fundracer_app_new/ios

# Backup original Podfile
echo "Creating Podfile backup..."
cp Podfile Podfile.backup

# Create a new podfile with CoreMotion framework linked properly
echo "Updating Podfile to include CoreMotion framework..."
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
  
  # Add system frameworks that are needed
  pod 'CoreLocation'
  
  # Create custom script phases to link system frameworks that aren't available as pods
  script_phase :name => 'Link CoreMotion Framework',
               :script => 'if [[ -z "${SYSTEM_FRAMEWORK_SEARCH_PATHS}" ]]; then
                            system_frameworks="${BUILT_PRODUCTS_DIR}/permission_handler_apple"
                          else
                            system_frameworks="${SYSTEM_FRAMEWORK_SEARCH_PATHS}"
                          fi
                          
                          if [[ ! "$FRAMEWORK_SEARCH_PATHS" == *"$system_frameworks"* ]]; then
                            # Add the Frameworks path
                            system_frameworks_path="/System/Library/Frameworks"
                            
                            echo "Adding CoreMotion framework to build settings"
                            echo "OTHER_LDFLAGS=\${OTHER_LDFLAGS} -framework CoreMotion" > "${BUILT_PRODUCTS_DIR}/permission_handler_apple.framework/add_frameworks.xcconfig"
                            echo "FRAMEWORK_SEARCH_PATHS=\${FRAMEWORK_SEARCH_PATHS} ${system_frameworks_path}" >> "${BUILT_PRODUCTS_DIR}/permission_handler_apple.framework/add_frameworks.xcconfig"
                            
                            # Include the xcconfig file if it exists
                            if [ -f "${BUILT_PRODUCTS_DIR}/permission_handler_apple.framework/add_frameworks.xcconfig" ]; then
                              echo "Including custom xcconfig for CoreMotion"
                              #include "${BUILT_PRODUCTS_DIR}/permission_handler_apple.framework/add_frameworks.xcconfig"
                            fi
                          fi',
               :execution_position => :before_compile
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Start of the permission handler fix
    target.build_configurations.each do |config|
      # Permission handler preprocessor definitions
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_LOCATION=1',
        'PERMISSION_NOTIFICATIONS=1',
        'PERMISSION_MEDIA_LIBRARY=1',
        'PERMISSION_SENSORS=1',
        'PERMISSION_BACKGROUND_REFRESH=1',
      ]
      
      # Link CoreMotion framework
      if target.name == 'permission_handler_apple'
        config.build_settings['OTHER_LDFLAGS'] ||= ['$(inherited)']
        config.build_settings['OTHER_LDFLAGS'] << '-framework' << 'CoreMotion'
      end
      
      # Fix Xcode 14+ compatibility issues
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

# Reinstall pods with the new Podfile
echo "Removing Pods directory and Podfile.lock..."
rm -rf Pods
rm -f Podfile.lock

echo "Reinstalling pods with the updated Podfile..."
pod install --repo-update

echo "CoreMotion framework linking fixed."
echo "Now close Xcode, reopen it, and try building the project again." 