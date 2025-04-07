#!/bin/bash

cd ios
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
    OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0" \
    WARNING_CFLAGS="-w" \
    clean build
