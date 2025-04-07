#!/bin/bash

# Clean build script implementing the Medium solution for BoringSSL-GRPC -G flag issue

echo "=== Building with BoringSSL-GRPC flag fix ==="

# Deep clean the project
echo "Deep cleaning the project..."
flutter clean
flutter pub get

# Deep clean iOS build
echo "Deep cleaning iOS build..."
cd ios
rm -rf Pods
rm -f Podfile.lock
rm -rf build
rm -rf DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*Runner*

# Fix potential recursive nesting issue
echo "Cleaning any nested build artifacts..."
find .. -path "*/build/ios/*Runner.app/Runner.app" -type d -exec rm -rf {} \; 2>/dev/null || true

# Run pod install with the modified Podfile (which already contains the fix)
echo "Running pod install with BoringSSL-GRPC fix..."
pod install

# Build the project
echo "Building iOS app..."
cd ..

# Clean build directory again to ensure no nested artifacts
rm -rf build/ios

flutter build ios --no-codesign 