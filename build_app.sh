#!/bin/bash

# Set up environment variables
export EXCLUDED_ARCHS=i386
export OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0"
export WARNING_CFLAGS="-w"

# Add EXTENSION=0 to xcconfig files
cd ..
find ../Flutter -name "*.xcconfig" -exec sed -i '' 's/GCC_PREPROCESSOR_DEFINITIONS = \$(inherited)/GCC_PREPROCESSOR_DEFINITIONS = $(inherited) EXTENSION=0/g' {} \;

# Clean and reinstall pods
rm -rf Pods Podfile.lock
pod install

# Build with xcodebuild
xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -sdk iphoneos \
    -arch arm64 \
    COMPILATION_MODE=wholemodule \
    COMPILER_INDEX_STORE_ENABLE=NO \
    GCC_PREPROCESSOR_DEFINITIONS='EXTENSION=0 COCOAPODS=1 OPENSSL_NO_ASM=1' \
    EXCLUDED_ARCHS=i386 \
    clean build 