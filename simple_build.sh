#!/bin/bash

# Set architecture
ARCH=arm64

# Set environment variables to fix the -G flag issue
export EXCLUDED_ARCHS=i386
export OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM"
export WARNING_CFLAGS="-w"

# Run flutter pub get to ensure Flutter dependencies are updated
cd ..
flutter pub get
cd ios

echo "Building with Xcode directly..."
xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -sdk iphoneos \
    -arch $ARCH \
    -allowProvisioningUpdates \
    COMPILER_INDEX_STORE_ENABLE=NO \
    build

BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
    echo "Build completed successfully!"
    echo "The built app can be found at: ios/build/Release-iphoneos/Runner.app"
else
    echo "Build failed with exit code $BUILD_STATUS"
fi

exit $BUILD_STATUS 