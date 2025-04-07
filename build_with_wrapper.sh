#!/bin/bash
export PATH="$PWD/ios/wrappers:$PATH"
echo "Building with modified PATH: $PATH"
flutter build ios --no-codesign
