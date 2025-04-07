#!/bin/bash

# This script is a simplified version of the BoringSSL fix
# It directly patches the source files and build settings for BoringSSL-GRPC

echo "=== Final Fix for BoringSSL-GRPC -G Flag Issue ==="

# Step 1: Clean the project
echo "Cleaning the project..."
cd ..
flutter clean

echo "Generating Flutter configuration files..."
flutter pub get

# Step 2: Change to iOS directory and prepare for pod install
echo "Preparing iOS build environment..."
cd ios
rm -rf Pods
rm -f Podfile.lock

# Step 3: Run pod install
echo "Running pod install..."
pod install

# Step 4: Find and replace all instances of the -G flag in Xcode configuration files
echo "Removing -G flag from Xcode configuration files..."
find Pods -name "*.xcconfig" -exec sed -i '' 's/-G//g' {} \;

# Step 5: Modify the Pods.xcodeproj/project.pbxproj file
echo "Removing -G flag from project.pbxproj..."
sed -i '' 's/-G//g' Pods/Pods.xcodeproj/project.pbxproj

# Step 6: Modify BoringSSL-GRPC build settings in project.pbxproj
echo "Adding OPENSSL_NO_ASM=1 to BoringSSL-GRPC targets..."
sed -i '' '/BoringSSL-GRPC/ {
    n; n; n; n; n;
    s/GCC_PREPROCESSOR_DEFINITIONS = "\$(inherited)"/GCC_PREPROCESSOR_DEFINITIONS = "$(inherited) OPENSSL_NO_ASM=1"/g
}' Pods/Pods.xcodeproj/project.pbxproj

# Step 7: Create a header file to define OPENSSL_NO_ASM
echo "Creating openssl_fix.h header..."
mkdir -p Pods/BoringSSL-GRPC/src/include/openssl/
cat > Pods/BoringSSL-GRPC/src/include/openssl/openssl_fix.h << 'EOF'
#ifndef OPENSSL_HEADER_OPENSSL_FIX_H
#define OPENSSL_HEADER_OPENSSL_FIX_H

#define OPENSSL_NO_ASM 1

#endif  // OPENSSL_HEADER_OPENSSL_FIX_H
EOF

# Step 8: Include the openssl_fix.h header in problematic files
FILES_TO_PATCH=(
  "Pods/BoringSSL-GRPC/src/ssl/handshake_client.cc"
  "Pods/BoringSSL-GRPC/src/ssl/ssl_aead_ctx.cc"
  "Pods/BoringSSL-GRPC/src/crypto/cipher_extra/e_aesgcmsiv.c" 
  "Pods/BoringSSL-GRPC/src/crypto/fipsmodule/cipher/cipher.c"
  "Pods/BoringSSL-GRPC/src/crypto/fipsmodule/self_check/fips.c"
  "Pods/BoringSSL-GRPC/src/crypto/fipsmodule/self_check/self_check.c"
)

for file in "${FILES_TO_PATCH[@]}"; do
  if [ -f "$file" ]; then
    echo "Patching $file..."
    # Insert include for openssl_fix.h after the first include
    sed -i '' '/#include/a\
#include <openssl/openssl_fix.h>
' "$file"
  fi
done

# Step 9: Create direct compiler flag interception
mkdir -p BoringSSL_Fix
cat > BoringSSL_Fix/wrapper.c << 'EOF'
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    char **new_args = (char **)malloc((argc + 5) * sizeof(char *));
    int new_idx = 0;
    int i;
    int is_boringssl = 0;

    // First argument is always the compiler path
    new_args[new_idx++] = strdup(argv[0]);
    
    // Check if we're compiling BoringSSL files
    for (i = 0; i < argc; i++) {
        if (argv[i] && (strstr(argv[i], "BoringSSL") || strstr(argv[i], "boringssl"))) {
            is_boringssl = 1;
            break;
        }
    }
    
    // Process remaining arguments, skipping -G flag
    for (i = 1; i < argc; i++) {
        if (argv[i] && strcmp(argv[i], "-G") == 0) {
            // Skip the -G flag
            continue;
        } else {
            new_args[new_idx++] = strdup(argv[i]);
        }
    }
    
    // Add OPENSSL_NO_ASM definition for BoringSSL files
    if (is_boringssl) {
        new_args[new_idx++] = strdup("-DOPENSSL_NO_ASM=1");
    }
    
    new_args[new_idx] = NULL;
    
    // Execute the real compiler with our modified arguments
    execvp(new_args[0], new_args);
    
    // If we get here, execution failed
    perror("execvp failed");
    return 1;
}
EOF

# Step 10: Compile and set up wrapper
echo "Creating compiler wrapper..."
gcc BoringSSL_Fix/wrapper.c -o BoringSSL_Fix/wrapper
chmod +x BoringSSL_Fix/wrapper

# Create wrapper scripts
cat > BoringSSL_Fix/clang << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/wrapper" /usr/bin/clang "$@"
EOF

cat > BoringSSL_Fix/clang++ << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/wrapper" /usr/bin/clang++ "$@"
EOF

chmod +x BoringSSL_Fix/clang BoringSSL_Fix/clang++

# Step 11: Enable workarounds for compiler
cat > workaround.xcconfig << 'EOF'
OTHER_CFLAGS = $(inherited) -Wno-error=incompatible-pointer-types
OTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-error=incompatible-pointer-types
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) OPENSSL_NO_ASM=1
VALID_ARCHS = arm64
ARCHS = arm64
EXCLUDED_ARCHS[sdk=iphonesimulator*] = i386
ENABLE_BITCODE = NO
EOF

echo "Adding workaround.xcconfig to build settings..."
find Pods/Target\ Support\ Files -name "BoringSSL-GRPC*.xcconfig" -exec cp workaround.xcconfig {} \;

# Step 12: Build the project
echo "Building the project..."
cd ..
echo "Please run the following command to build your project with the modified environment:"
echo "export PATH=\"$PWD/ios/BoringSSL_Fix:\$PATH\" && flutter build ios --no-codesign"

# Create a convenience script
cat > build_with_wrapper.sh << 'EOF'
#!/bin/bash
export PATH="$PWD/ios/BoringSSL_Fix:$PATH"
echo "Building with wrapper in PATH: $PATH"
flutter build ios --no-codesign
EOF
chmod +x build_with_wrapper.sh

echo "Alternatively, run: ./build_with_wrapper.sh" 