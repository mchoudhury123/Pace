#!/bin/bash

echo "Fixing BoringSSL build issues..."

# Navigate to the iOS directory
cd "$(dirname "$0")"

# Clean CocoaPods cache and reinstall
echo "Cleaning CocoaPods cache and projects..."
rm -rf ~/Library/Caches/CocoaPods
rm -rf Pods
rm -rf Podfile.lock

# Backup the original Podfile
cp Podfile Podfile.bak

# Create a new post_install hook for the Podfile
echo "Creating a clean Podfile with fixed post_install hook..."
cat > Podfile.new << 'EOL'
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
    
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      
      # Fix for BoringSSL-GRPC and related targets
      if target.name == 'BoringSSL-GRPC' || target.name.include?('gRPC') || target.name.include?('openssl')
        puts "Fixing build settings for target: #{target.name}"
        
        # Remove problematic flags
        if config.build_settings['OTHER_CFLAGS']
          config.build_settings['OTHER_CFLAGS'] = config.build_settings['OTHER_CFLAGS'].gsub(/-G/, '')
        end
        
        if config.build_settings['GCC_CFLAGS']
          config.build_settings['GCC_CFLAGS'] = config.build_settings['GCC_CFLAGS'].gsub(/-G/, '')
        end
        
        # Add NO_ASM definition
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'OPENSSL_NO_ASM=1'
        
        # Add explicit architecture settings
        config.build_settings['ARCHS'] = 'arm64'
        config.build_settings['VALID_ARCHS'] = 'arm64'
        
        # Other settings that might help
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
      end
    end
  end
end
EOL

# Find and fix the -G flag in existing project files
echo "Removing -G and -gmodules flags from project files..."
find . -name "*.xcconfig" -exec sed -i '' 's/-G//g' {} \;
find . -name "*.xcconfig" -exec sed -i '' 's/-gmodules//g' {} \;
find . -name "*.pbxproj" -exec sed -i '' 's/-G//g' {} \;
find . -name "*.pbxproj" -exec sed -i '' 's/-gmodules//g' {} \;

# Compare with original Podfile to ensure we haven't missed anything
echo "Checking customizations in the original Podfile..."
ORIGINAL_CUSTOM_CONTENT=$(grep -v -E "^(#|$|require |flutter_|platform :|ENV|project |def |target |post_install |end|use_)" Podfile.bak)

if [ -n "$ORIGINAL_CUSTOM_CONTENT" ]; then
  echo "Found custom content in original Podfile. You may need to manually merge this:"
  echo "$ORIGINAL_CUSTOM_CONTENT"
  
  # Keep backup for reference
  echo "Original Podfile kept as Podfile.bak for reference"
else
  # Replace with our new clean version
  echo "Replacing Podfile with clean version"
  mv Podfile.new Podfile
fi

# Install Pods with the updated Podfile
echo "Running pod install..."
pod install

# Fix the Pods project directly after pod install
echo "Creating direct project fix script..."
cat > fix_pods_project.rb << 'EOL'
#!/usr/bin/env ruby

require 'xcodeproj'

# Fix the Pods project directly
def fix_pods_project
  puts "Directly fixing Pods.xcodeproj..."
  
  begin
    project_path = 'Pods/Pods.xcodeproj'
    unless File.exist?(project_path)
      puts "Error: #{project_path} does not exist"
      return false
    end
    
    project = Xcodeproj::Project.open(project_path)
    
    # Look for targets to fix
    targets_to_fix = project.targets.select do |target|
      target.name == 'BoringSSL-GRPC' || target.name.include?('gRPC') || target.name.include?('openssl')
    end
    
    puts "Found #{targets_to_fix.length} targets to fix"
    
    targets_to_fix.each do |target|
      puts "Fixing target: #{target.name}"
      
      target.build_configurations.each do |config|
        # Remove -G flag from all compiler flags
        %w[GCC_CFLAGS OTHER_CFLAGS].each do |flag_name|
          if config.build_settings[flag_name]
            puts "  Fixing #{flag_name} in #{config.name}"
            config.build_settings[flag_name] = config.build_settings[flag_name].to_s.gsub(/-G/, '')
          end
        end
        
        # Add preprocessor definitions
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'OPENSSL_NO_ASM=1'
        
        # Set other required build settings
        config.build_settings['ARCHS'] = 'arm64'
        config.build_settings['VALID_ARCHS'] = 'arm64'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        
        puts "  - Fixed configuration: #{config.name}"
      end
    end
    
    # Fix file build settings directly
    project.files.each do |file|
      file_path = file.path
      
      # Check if file is part of BoringSSL
      if file_path && (file_path.include?('boringssl') || file_path.include?('grpc'))
        file.build_settings.each do |build_setting|
          if build_setting['GCC_CFLAGS']
            build_setting['GCC_CFLAGS'] = build_setting['GCC_CFLAGS'].to_s.gsub(/-G/, '')
          end
          if build_setting['OTHER_CFLAGS']
            build_setting['OTHER_CFLAGS'] = build_setting['OTHER_CFLAGS'].to_s.gsub(/-G/, '')
          end
          
          # Add OPENSSL_NO_ASM to build settings
          build_setting['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
          build_setting['GCC_PREPROCESSOR_DEFINITIONS'] << 'OPENSSL_NO_ASM=1'
        end
      end
    end
    
    # Save the project
    project.save
    puts "Successfully fixed Pods.xcodeproj"
    return true
  rescue => e
    puts "Error fixing Pods.xcodeproj: #{e.message}"
    puts e.backtrace.join("\n")
    return false
  end
end

# Execute the fix
fix_pods_project
EOL

# Make the script executable
chmod +x fix_pods_project.rb

# Run the script to fix the project directly
echo "Running project fix script..."
ruby fix_pods_project.rb

echo "Fix complete. Please try building your project again using:"
echo "flutter build ios --no-codesign"