#!/bin/bash
export PATH="$PWD/ios/wrappers:$PATH"
export IPHONEOS_DEPLOYMENT_TARGET=14.0
export NO_G_FLAG=1
flutter build ios --no-codesign
