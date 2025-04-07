#!/bin/bash

# Simple script to fix the -G flag issue in BoringSSL-GRPC

echo "=== Simple Fix for BoringSSL-GRPC -G Flag Issue ==="

# Make sure we're in the right directory
cd "$(dirname "$0")"

# Step 1: Run pod install
echo "Running pod install..."
pod install

# Step 2: Find and replace all instances of the -G flag in Xcode configuration files
echo "Removing -G flag from Xcode configuration files..."
find Pods -name "*.xcconfig" -exec sed -i '' 's/-G//g' {} \;

# Step 3: Also replace in project.pbxproj
echo "Removing -G flag from project.pbxproj..."
sed -i '' 's/-G//g' Pods/Pods.xcodeproj/project.pbxproj

# Step 4: Create a special configuration file for BoringSSL
echo "Creating special configuration for BoringSSL-GRPC..."
cat > boringssl_fix.xcconfig << 'EOF'
OTHER_CFLAGS = $(inherited) -Wno-error=incompatible-pointer-types -DOPENSSL_NO_ASM=1
OTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-error=incompatible-pointer-types -DOPENSSL_NO_ASM=1
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) OPENSSL_NO_ASM=1
VALID_ARCHS = arm64
ARCHS = arm64
EXCLUDED_ARCHS[sdk=iphonesimulator*] = i386
ENABLE_BITCODE = NO
EOF

# Step 5: Apply configuration to all BoringSSL build configurations
echo "Applying configuration to BoringSSL build settings..."
for config in Pods/Target\ Support\ Files/BoringSSL-GRPC/*.xcconfig; do
  if [ -f "$config" ]; then
    echo "Patching $config..."
    cat boringssl_fix.xcconfig >> "$config"
  fi
done

echo "Fix completed. Now try building your Flutter project with:"
echo "cd .. && flutter build ios --no-codesign" 