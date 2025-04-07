#!/bin/bash

# Clean and reinstall pods
cd ios
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
pod install

# Set environment variables
export EXTENSION=1
export NO_FLIPPER=1

# Build the app with custom xcconfig
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos \
  GCC_PREPROCESSOR_DEFINITIONS="$GCC_PREPROCESSOR_DEFINITIONS COCOAPODS=1 EXTENSION=1" \
  DEVELOPMENT_TEAM="3XDM85H9UV" -xcconfig ../exclude_leveldb.xcconfig \
  clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
