#!/bin/bash

cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

pod install --repo-update

cd ..

export EXCLUDED_ARCHS="i386 armv7 armv7s armv6 x86_64"
export ARCHS="arm64"

xcodebuild -quiet -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release
