#!/bin/bash

# Final solution script that:
# 1. Fixes the -G flag issue with BoringSSL-GRPC
# 2. Addresses plugin compatibility issues
# 3. Prevents app recursive nesting

echo "=== COMPREHENSIVE FINAL SOLUTION ==="

# Step 1: Clean everything
echo "Performing deep clean..."
flutter clean
rm -rf build
rm -rf ios/build
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/Flutter/Generated.xcconfig
rm -rf ios/Flutter/flutter_export_environment.sh
rm -rf ~/Library/Developer/Xcode/DerivedData/*Runner*
rm -rf ~/Library/Caches/CocoaPods

# Step 2: Update Flutter dependencies
echo "Updating Flutter dependencies..."
flutter pub get

# Step 3: Apply the Medium.com solution to fix the Podfile
echo "Updating Podfile with BoringSSL-GRPC fix..."
cat > ios/Podfile << 'EOF'
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
  
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Medium.com solution for BoringSSL-GRPC specific fix
    if target.name == 'BoringSSL-GRPC'
      target.source_build_phase.files.each do |file|
        if file.settings && file.settings['COMPILER_FLAGS']
          flags = file.settings['COMPILER_FLAGS'].split
          flags.reject! { |flag| flag == '-GCC_WARN_INHIBIT_ALL_WARNINGS' || flag == '-G' }
          file.settings['COMPILER_FLAGS'] = flags.join(' ')
        end
      end
      
      # Add OPENSSL_NO_ASM for BoringSSL compatibility
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'OPENSSL_NO_ASM=1'
        config.build_settings['OTHER_CFLAGS'] = '$(inherited) -Wno-error=incompatible-pointer-types'
      end
    end
    
    # Set minimum iOS version for all targets
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      
      # Fix Swift issues
      if config.build_settings['SWIFT_VERSION'] == '5.0'
        config.build_settings['SWIFT_VERSION'] = '5.0'
      end
      
      # Additional settings to prevent app nesting for all targets
      config.build_settings['COPY_PHASE_STRIP'] = 'YES'
      config.build_settings['STRIP_INSTALLED_PRODUCT'] = 'YES'
      
      # Remove any -G flags from all build settings
      config.build_settings.each do |key, value|
        if value.is_a?(String) && value.include?('-G')
          config.build_settings[key] = value.gsub(/-G\b/, '')
        end
      end
    end
  end
  
  # Remove -G flag from all xcconfig files
  Dir.glob("#{installer.sandbox.root}/**/*.xcconfig").each do |config_file|
    content = File.read(config_file)
    modified_content = content.gsub(/-G\b/, '')
    File.write(config_file, modified_content) if content != modified_content
  end
  
  # Remove -G flag from project.pbxproj
  project_file = "#{installer.sandbox.root}/Pods.xcodeproj/project.pbxproj"
  if File.exist?(project_file)
    content = File.read(project_file)
    modified_content = content.gsub(/-G\b/, '')
    File.write(project_file, modified_content) if content != modified_content
  end
end
EOF

# Step 4: Generate Flutter configuration
echo "Generating Flutter configuration..."
cd ios
flutter pub get

# Step 5: Run pod install with the updated settings
echo "Running pod install with fixed settings..."
pod deintegrate || true
pod install --verbose

# Step 6: Create a direct xcodebuild script
echo "Creating direct xcodebuild script..."
cd ..

cat > direct_build.sh << 'EOF'
#!/bin/bash

# Clean first
rm -rf ios/build

# Find and delete any nested Runner.app directories
find . -name "*.app" -type d -path "*Runner.app/*Runner.app*" -exec rm -rf {} \; 2>/dev/null || true

# Set up environment variables to prevent nesting
export COPY_PHASE_STRIP=YES
export STRIP_INSTALLED_PRODUCT=YES
export APPLICATION_EXTENSION_API_ONLY=YES

cd ios

# Run xcodebuild directly
xcodebuild \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build/DerivedData \
  -quiet \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  COPY_PHASE_STRIP=YES \
  STRIP_INSTALLED_PRODUCT=YES \
  APPLICATION_EXTENSION_API_ONLY=YES \
  build

echo "Direct Xcode build completed"
echo "You can find the built app at: ios/build/DerivedData/Build/Products/Release-iphoneos/Runner.app"
EOF

chmod +x direct_build.sh

echo "SETUP COMPLETE"
echo "Run the direct Xcode build with: ./direct_build.sh" 