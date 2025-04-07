#!/bin/bash

# This script addresses the issue with the -G flag in BoringSSL-GRPC for iOS 14.0 builds

echo "=== COMPREHENSIVE SOLUTION FOR BORINGSSL-GRPC BUILD ISSUE ==="

# Clean the project
echo "Cleaning the project..."
flutter clean
flutter pub get

# Clean iOS build
echo "Cleaning iOS build..."
cd ios
rm -rf Pods
rm -f Podfile.lock
rm -rf build
rm -rf DerivedData

# Create openssl_fix.h header to be included in problematic files
echo "Creating openssl_fix.h header..."
cat > openssl_fix.h << 'EOF'
#ifndef OPENSSL_HEADER_OPENSSL_FIX_H
#define OPENSSL_HEADER_OPENSSL_FIX_H

#define OPENSSL_NO_ASM 1

#endif  // OPENSSL_HEADER_OPENSSL_FIX_H
EOF

# Create compiler wrappers to filter out -G flag
echo "Setting up compiler wrappers..."
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

# Set environment variable for our compiler wrappers
export PATH="$(pwd)/wrappers:$PATH"

# Run pod install
echo "Running pod install with compiler wrappers..."
pod install

# Patch files
echo "Patching BoringSSL-GRPC configuration files..."

# Remove -G flag from configuration files
find Pods -name "*.xcconfig" -exec sed -i '' 's/-G//g' {} \;
find Pods -name "*.pbxproj" -exec sed -i '' 's/-G//g' {} \;

# Patch all BoringSSL-GRPC configuration files
for config in Pods/Target\ Support\ Files/BoringSSL-GRPC/*.xcconfig; do
  if [ -f "$config" ]; then
    echo "Patching $config..."
    cat >> "$config" << 'EOF'
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) OPENSSL_NO_ASM=1
OTHER_CFLAGS = $(inherited) -Wno-error=incompatible-pointer-types -DOPENSSL_NO_ASM=1
OTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-error=incompatible-pointer-types -DOPENSSL_NO_ASM=1
HEADER_SEARCH_PATHS = $(inherited) "${PODS_ROOT}/Headers/Public" "${PODS_TARGET_SRCROOT}/include"
ARCHS = arm64
VALID_ARCHS = arm64
ENABLE_BITCODE = NO
EOF
  fi
done

# Add our openssl_fix.h header to BoringSSL includes
mkdir -p Pods/BoringSSL-GRPC/src/include/openssl
cp openssl_fix.h Pods/BoringSSL-GRPC/src/include/openssl/

# Patch problematic source files
echo "Patching source files..."
PROBLEM_FILES=(
  "Pods/BoringSSL-GRPC/src/ssl/handshake_client.cc"
  "Pods/BoringSSL-GRPC/src/ssl/ssl_aead_ctx.cc"
  "Pods/BoringSSL-GRPC/src/crypto/cipher_extra/e_aesgcmsiv.c"
  "Pods/BoringSSL-GRPC/src/crypto/fipsmodule/cipher/cipher.c"
  "Pods/BoringSSL-GRPC/src/crypto/fipsmodule/self_check/fips.c"
  "Pods/BoringSSL-GRPC/src/crypto/fipsmodule/self_check/self_check.c"
)

for file in "${PROBLEM_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "Patching $file..."
    awk 'NR==1{print "#include <openssl/openssl_fix.h>"}1' "$file" > "$file.temp"
    mv "$file.temp" "$file"
  fi
done

# Create a shell script to build with our compiler wrapper
cd ..
cat > build_fixed.sh << 'EOF'
#!/bin/bash
export PATH="$PWD/ios/wrappers:$PATH"
export IPHONEOS_DEPLOYMENT_TARGET=14.0
cd ios
find Pods -name "*.xcconfig" -exec sed -i '' 's/-G//g' {} \;
find Pods -name "*.pbxproj" -exec sed -i '' 's/-G//g' {} \;
cd ..
flutter build ios --no-codesign
EOF
chmod +x build_fixed.sh

echo "Setup complete. Run the build with:"
echo "./build_fixed.sh" 