#!/bin/bash

# Find all xcconfig files in the Flutter directory
find ../Flutter -name "*.xcconfig" -exec sed -i '' 's/GCC_PREPROCESSOR_DEFINITIONS = \$(inherited)/GCC_PREPROCESSOR_DEFINITIONS = $(inherited) EXTENSION=0/g' {} \;
