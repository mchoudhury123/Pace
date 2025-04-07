#!/bin/bash

echo "Starting Firebase dependency cycle fix..."

# Set path to Podfile
PODFILE_PATH="ios/Podfile"

# Check if Podfile exists
if [ ! -f "$PODFILE_PATH" ]; then
  echo "Error: Podfile not found at $PODFILE_PATH"
  exit 1
fi

# Create a backup of the Podfile
cp "$PODFILE_PATH" "${PODFILE_PATH}.backup"
echo "Created backup of Podfile at ${PODFILE_PATH}.backup"

# Add post_install hook to break the dependency cycle
# We'll add a post_install hook if it doesn't exist or append to the existing one
if grep -q "post_install do |installer|" "$PODFILE_PATH"; then
  # Find the end of the post_install block and insert before it
  sed -i '' '/end # post_install/i\
  # Fix Firebase dependency cycle\
  installer.pods_project.targets.each do |target|\
    if [%q{FirebaseCoreInternal-FirebaseCoreInternal_Privacy}.include?(target.name)\
      target.build_configurations.each do |config|\
        config.build_settings["OTHER_LDFLAGS"] = "$(inherited) -framework Foundation"\
      end\
    end\
  end\
' "$PODFILE_PATH"
else
  # Add a new post_install hook at the end of the file
  cat << 'EOF' >> "$PODFILE_PATH"

post_install do |installer|
  # Fix Firebase dependency cycle
  installer.pods_project.targets.each do |target|
    if ['FirebaseCoreInternal-FirebaseCoreInternal_Privacy'].include?(target.name)
      target.build_configurations.each do |config|
        config.build_settings["OTHER_LDFLAGS"] = "$(inherited) -framework Foundation"
      end
    end
  end
  
  # This is necessary for Xcode 14
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
      config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
      config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
    end
  end
end
EOF
fi

echo "Modified Podfile to fix Firebase dependency cycle"

# Create a final build script
cat > ios_final_build_with_firebase_cycle_fix.sh << 'EOF'
#!/bin/bash

echo "Starting final build with Firebase dependency cycle fix..."
cd ios

# Clean and reinstall pods
echo "Cleaning and reinstalling CocoaPods..."
pod deintegrate
rm -rf Pods Podfile.lock
pod install

# Set environment variables
export EXCLUDED_ARCHS="i386 armv7"

# Run the build command with excluded archs
echo "Building iOS app..."
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -allowProvisioningUpdates build

echo "iOS build completed."
EOF

# Make the build script executable
chmod +x ios_final_build_with_firebase_cycle_fix.sh

echo "Firebase dependency cycle fix completed. Run ./ios_final_build_with_firebase_cycle_fix.sh to build the app." 