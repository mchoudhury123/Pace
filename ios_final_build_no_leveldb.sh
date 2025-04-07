#!/bin/bash

echo "=== Starting iOS final build with leveldb workaround ==="

# Set environment variables for building
export EXCLUDED_ARCHS=i386
export OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0"

# Clean the build directory
cd ios
rm -rf build
mkdir -p build

# Build the app with the modified settings
echo "Building the iOS app..."
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -sdk iphoneos \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  COMPILATION_MODE=wholemodule \
  GCC_PREPROCESSOR_DEFINITIONS="EXTENSION=0 COCOAPODS=1 OPENSSL_NO_ASM=1 LEVELDB_PLATFORM_POSIX=1 OS_MACOSX=1" \
  OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0" \
  EXCLUDED_ARCHS=i386 \
  EXCLUDED_SOURCE_FILE_NAMES="version_set.cc version_edit.cc table_builder.cc" \
  build

echo "=== iOS build completed ==="
