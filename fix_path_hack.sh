#!/bin/bash

# This is the final build script with PATH override
echo "=== FINAL BUILD WITH PATH OVERRIDE ==="

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

# Run pod install with our modified Podfile that intercepts the compiler
echo "Running pod install with compiler interception..."
pod install

# Just in case, also directly replace any -G flags in the build files
echo "Double-checking all files for -G flags..."
find Pods -name "*.xcconfig" -exec sed -i '' 's/-G//g' {} \;
find Pods -name "*.pbxproj" -exec sed -i '' 's/-G//g' {} \;

# Set up compiler wrappers for the Flutter build
echo "Setting up compiler wrappers for Flutter build..."
mkdir -p global_wrappers

cat > global_wrappers/clang << 'EOF'
#!/bin/bash
args=()
for arg in "$@"; do
  if [ "$arg" != "-G" ] && [ "$arg" != "-gmodules" ]; then
    args+=("$arg")
  fi
done
exec /usr/bin/clang "${args[@]}"
EOF

cat > global_wrappers/clang++ << 'EOF'
#!/bin/bash
args=()
for arg in "$@"; do
  if [ "$arg" != "-G" ] && [ "$arg" != "-gmodules" ]; then
    args+=("$arg")
  fi
done
exec /usr/bin/clang++ "${args[@]}"
EOF

chmod +x global_wrappers/clang global_wrappers/clang++

# Create a special configuration for BoringSSL and any grpc targets
echo "Creating special configuration for BoringSSL..."
cat > boringssl_fix.xcconfig << 'EOF'
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) OPENSSL_NO_ASM=1
OTHER_CFLAGS = $(inherited) -Wno-error=incompatible-pointer-types -DOPENSSL_NO_ASM=1
OTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-error=incompatible-pointer-types -DOPENSSL_NO_ASM=1
ARCHS = arm64
VALID_ARCHS = arm64
ENABLE_BITCODE = NO
EOF

for config in Pods/Target\ Support\ Files/BoringSSL-GRPC/*.xcconfig; do
  echo "Patching $config..."
  cat boringssl_fix.xcconfig >> "$config"
done

# Set environment for the flutter build
cd ..
echo "Building with compiler wrappers in PATH..."
export PATH="$PWD/ios/global_wrappers:$PATH"
export FLUTTER_XCODE_ONLY_ACTIVE_ARCH=YES

# Add explicit environment variable to tell the compiler to skip -G
export COMPILER_SKIP_FLAG_G=1

# Run the build
echo "Running the build..."
flutter build ios --no-codesign 