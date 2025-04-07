#!/bin/bash

# Direct fix for unsupported -G flag issue in BoringSSL-GRPC
# This script creates a more aggressive solution that modifies the Xcode environment

echo "=== Direct Fix for BoringSSL-GRPC -G Flag Issue ==="

# Step 1: Clean the project
echo "Cleaning the project..."
flutter clean

echo "Generating Flutter configuration files..."
flutter pub get

# Step 2: Change to iOS directory and update Podfile
echo "Updating Podfile with special post-install hook..."
cd ios
rm -rf Pods
rm -f Podfile.lock
rm -rf build
rm -rf DerivedData

cat > Podfile << 'EOF'
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
    
    target.build_configurations.each do |config|
      config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "14.0"
      
      # Remove -G flag from all configuration settings
      config.build_settings.each do |key, value|
        if value.is_a?(String) && value.include?("-G")
          puts "Removing -G from #{key} in #{target.name}"
          config.build_settings[key] = value.gsub(/-G\b/, "")
        end
      end
      
      # Handle BoringSSL-GRPC and gRPC targets specifically
      if target.name.include?("BoringSSL") || target.name.include?("gRPC")
        puts "Adding special configuration for #{target.name}"
        
        # Set preprocessor definitions for OPENSSL_NO_ASM
        if config.build_settings["GCC_PREPROCESSOR_DEFINITIONS"].nil?
          config.build_settings["GCC_PREPROCESSOR_DEFINITIONS"] = ["$(inherited)", "OPENSSL_NO_ASM=1"]
        else
          config.build_settings["GCC_PREPROCESSOR_DEFINITIONS"] << "OPENSSL_NO_ASM=1"
        end
        
        # Set architecture explicitly to arm64
        config.build_settings["ARCHS"] = "arm64"
        config.build_settings["VALID_ARCHS"] = "arm64"
        
        # Add compatibility flags for warnings
        existing_cflags = config.build_settings["OTHER_CFLAGS"] || "$(inherited)"
        config.build_settings["OTHER_CFLAGS"] = "#{existing_cflags} -Wno-error=incompatible-pointer-types"
        
        # Disable bitcode
        config.build_settings["ENABLE_BITCODE"] = "NO"
      end
    end
  end
end
EOF

# Step 3: Create wrapper scripts to intercept compiler flags
echo "Creating compiler wrapper scripts..."
mkdir -p wrappers

cat > wrappers/clang << 'EOF'
#!/bin/bash
args=()
for arg in "$@"; do
  if [ "$arg" != "-G" ] && [ "$arg" != "-gmodules" ]; then
    args+=("$arg")
  fi
done
exec /usr/bin/clang "${args[@]}"
EOF

cat > wrappers/clang++ << 'EOF'
#!/bin/bash
args=()
for arg in "$@"; do
  if [ "$arg" != "-G" ] && [ "$arg" != "-gmodules" ]; then
    args+=("$arg")
  fi
done
exec /usr/bin/clang++ "${args[@]}"
EOF

chmod +x wrappers/clang wrappers/clang++

# Step 4: Run pod install
echo "Running pod install with modified Podfile..."
pod install

# Step 5: Find and replace all instances of the -G flag in Xcode configuration files
echo "Removing -G flag from Xcode configuration files..."
find Pods -name "*.xcconfig" -type f -exec sed -i '' 's/-G//g' {} \;

# Also replace in project.pbxproj
echo "Removing -G flag from project.pbxproj..."
sed -i '' 's/-G//g' Pods/Pods.xcodeproj/project.pbxproj

# Step 6: Create a special configuration file for BoringSSL
echo "Creating special configuration for BoringSSL-GRPC..."
cat > boringssl_fix.xcconfig << 'EOF'
OTHER_CFLAGS = $(inherited) -Wno-error=incompatible-pointer-types -DOPENSSL_NO_ASM=1
OTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-error=incompatible-pointer-types -DOPENSSL_NO_ASM=1
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) OPENSSL_NO_ASM=1
ARCHS = arm64
VALID_ARCHS = arm64
ENABLE_BITCODE = NO
EOF

# Apply configuration to all BoringSSL build configurations
echo "Applying configuration to BoringSSL build settings..."
for config in Pods/Target\ Support\ Files/BoringSSL-GRPC/*.xcconfig; do
  if [ -f "$config" ]; then
    echo "Patching $config..."
    cat boringssl_fix.xcconfig >> "$config"
  fi
done

# Create build script that uses our wrapper
cd ..
cat > build_with_wrapper.sh << 'EOF'
#!/bin/bash
export PATH="$PWD/ios/wrappers:$PATH"
echo "Building with modified PATH: $PATH"
flutter build ios --no-codesign
EOF
chmod +x build_with_wrapper.sh

echo "Fix applied. To build the project with the modified settings, run:"
echo "./build_with_wrapper.sh" 