#!/bin/bash
export DYLD_INSERT_LIBRARIES="$(pwd)/ios/direct_compiler_hook.so"
echo "Building with DYLD_INSERT_LIBRARIES=$DYLD_INSERT_LIBRARIES"
flutter build ios --no-codesign
