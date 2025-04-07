#!/bin/bash

# Build and use the direct compiler hook to prevent -G flag usage

echo "=== USING DIRECT COMPILER HOOK ==="

# Compile the hook
echo "Compiling direct compiler hook..."
gcc -shared -fPIC -o direct_compiler_hook.so direct_compiler_hook.c -ldl

# Clean the project
echo "Cleaning the project..."
cd ..
flutter clean
flutter pub get

# Clean iOS build
echo "Cleaning iOS build..."
cd ios
rm -rf Pods
rm -f Podfile.lock

# Run pod install with our hook
echo "Running pod install with compiler hook..."
DYLD_INSERT_LIBRARIES="$(pwd)/direct_compiler_hook.so" pod install

# Remove any remaining -G flags
echo "Removing any remaining -G flags from configuration files..."
find Pods -name "*.xcconfig" -exec sed -i '' 's/-G//g' {} \;
find Pods -name "*.pbxproj" -exec sed -i '' 's/-G//g' {} \;

# Patch BoringSSL-GRPC targets
echo "Patching BoringSSL-GRPC targets..."
for config in Pods/Target\ Support\ Files/BoringSSL-GRPC/*.xcconfig; do
  if [ -f "$config" ]; then
    echo "Patching $config..."
    echo "GCC_PREPROCESSOR_DEFINITIONS = \$(inherited) OPENSSL_NO_ASM=1" >> "$config"
    echo "OTHER_CFLAGS = \$(inherited) -Wno-error=incompatible-pointer-types -DOPENSSL_NO_ASM=1" >> "$config"
    echo "ARCHS = arm64" >> "$config"
    echo "VALID_ARCHS = arm64" >> "$config"
    echo "ENABLE_BITCODE = NO" >> "$config"
  fi
done

# Create interceptor script for the flutter build
cd ..
cat > build_with_hook.sh << 'EOF'
#!/bin/bash
export DYLD_INSERT_LIBRARIES="$(pwd)/ios/direct_compiler_hook.so"
echo "Building with DYLD_INSERT_LIBRARIES=$DYLD_INSERT_LIBRARIES"
flutter build ios --no-codesign
EOF
chmod +x build_with_hook.sh

echo "Now run ./build_with_hook.sh to build with the compiler hook." 