#!/bin/bash

# This script specifically addresses the recursive app nesting issue that leads to 
# 'is longer than filepath buffer size (1025)' errors

echo "=== FIXING RECURSIVE APP NESTING ISSUE ==="

# Clean ALL possible nested build artifacts
echo "Cleaning all build directories..."
rm -rf build
rm -rf ios/build
rm -rf ~/Library/Developer/Xcode/DerivedData/*Runner*
rm -rf ~/Library/Caches/CocoaPods
rm -rf ios/DerivedData
rm -rf ios/Pods
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/Flutter/Generated.xcconfig
rm -rf ios/Flutter/flutter_export_environment.sh

# Fix Xcode project settings to prevent recursive copying
echo "Fixing Xcode project settings..."
cd ios

# Find and delete any nested Runner.app directories
find .. -name "*.app" -type d -path "*Runner.app/*Runner.app*" -exec rm -rf {} \; 2>/dev/null || true

# Create a temporary script to modify the Xcode project
cat > fix_copy_phase.rb << 'EOF'
#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == 'Runner' }
if target
  # Modify copy phase to prevent recursive copying
  target.build_phases.each do |phase|
    if phase.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase)
      # Check for recursive file references and remove them
      phase.files.each do |file|
        if file.file_ref && file.file_ref.path && file.file_ref.path.include?('Runner.app')
          puts "Removing recursive reference: #{file.file_ref.path}"
          phase.remove_build_file(file)
        end
      end
    end
  end
  
  # Set SKIP_INSTALL to YES for the target
  target.build_configurations.each do |config|
    config.build_settings['SKIP_INSTALL'] = 'NO'
    config.build_settings['COPY_PHASE_STRIP'] = 'YES'
    config.build_settings['STRIP_INSTALLED_PRODUCT'] = 'YES'
  end
  
  project.save
  puts "Fixed Xcode project settings."
else
  puts "Could not find Runner target."
end
EOF

# Make the Ruby script executable
chmod +x fix_copy_phase.rb

# Check if Ruby is available and xcodeproj gem is installed
if command -v ruby >/dev/null 2>&1; then
  if gem list -i xcodeproj >/dev/null 2>&1; then
    ruby fix_copy_phase.rb
  else
    echo "Installing xcodeproj gem..."
    gem install xcodeproj
    ruby fix_copy_phase.rb
  fi
else
  echo "Ruby is not available. Skipping Xcode project fix."
fi

# Generate a clean Flutter configuration
echo "Regenerating Flutter configuration..."
cd ..
flutter clean
flutter pub get

# Generate clean iOS project
echo "Rebuilding iOS project..."
cd ios
pod deintegrate || true
pod setup
pod install

echo "Setup complete! Now try building with:"
echo "flutter build ios --no-codesign" 