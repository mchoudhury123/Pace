#!/bin/bash

# This script is a custom build process for the Flutter project
# It specifically addresses issues with the -G flag in BoringSSL-GRPC

echo "=== Custom Flutter Build for iOS ==="

# Clean the project
echo "Cleaning project..."
flutter clean

# Start with a fresh Pod install
echo "Removing Pods directory..."
cd ios
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

echo "Modifying Podfile to avoid -G flag..."
cat > podfile_post_install_hook.rb << 'EOF'
# Additional post-install hook to modify compiler flags
installer.pods_project.targets.each do |target|
  target.build_configurations.each do |config|
    # Remove -G flag from compiler flags
    config.build_settings.each do |key, value|
      if value.is_a?(String) && (key.start_with?("OTHER_") || key.include?("FLAGS"))
        config.build_settings[key] = value.gsub(/-G\b/, "").gsub(/-gmodules\b/, "")
      end
    end
    
    # For BoringSSL-GRPC and related targets
    if target.name.include?("BoringSSL") || target.name.include?("gRPC")
      # Add OPENSSL_NO_ASM preprocessor definition
      if config.build_settings["GCC_PREPROCESSOR_DEFINITIONS"]
        config.build_settings["GCC_PREPROCESSOR_DEFINITIONS"] << "OPENSSL_NO_ASM=1"
      else
        config.build_settings["GCC_PREPROCESSOR_DEFINITIONS"] = ["$(inherited)", "OPENSSL_NO_ASM=1"]
      end
      
      # Set architecture explicitly
      config.build_settings["ARCHS"] = "arm64"
      config.build_settings["VALID_ARCHS"] = "arm64"
      
      # Add compiler flags to handle warnings
      existing_cflags = config.build_settings["OTHER_CFLAGS"] || "$(inherited)"
      config.build_settings["OTHER_CFLAGS"] = "#{existing_cflags} -Wno-error=incompatible-pointer-types"
    end
  end
end
EOF

echo "Adding post-install hook to Podfile..."
sed -i '' -e '/post_install do |installer|/,/end/c\
post_install do |installer|\
  installer.pods_project.targets.each do |target|\
    flutter_additional_ios_build_settings(target)\
    \
    target.build_configurations.each do |config|\
      config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "14.0"\
    end\
  end\
  \
  # Custom hook to fix BoringSSL\
  load "./podfile_post_install_hook.rb"\
end\
' Podfile

echo "Installing Pods with modified Podfile..."
pod install

echo "Setting up environment variables to disable -G flag..."
cd ..

# Create a helper script to detect and remove -G flag
cat > ios/remove_g_flag.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    char **new_argv = (char **)malloc((argc + 2) * sizeof(char *));
    int new_argc = 0;
    char *real_compiler = argv[1];
    
    // Skip the first argument (ourselves) and the second (real compiler)
    for (int i = 2; i < argc; i++) {
        // Skip -G and -gmodules flags
        if (strcmp(argv[i], "-G") == 0 || 
            strcmp(argv[i], "-gmodules") == 0) {
            continue;
        }
        new_argv[new_argc++] = argv[i];
    }
    
    // Add OPENSSL_NO_ASM for BoringSSL files
    int has_boringssl = 0;
    for (int i = 0; i < argc; i++) {
        if (strstr(argv[i], "BoringSSL") || 
            strstr(argv[i], "boringssl") || 
            strstr(argv[i], "grpc") || 
            strstr(argv[i], "gRPC")) {
            has_boringssl = 1;
            break;
        }
    }
    
    if (has_boringssl) {
        new_argv[new_argc++] = "-DOPENSSL_NO_ASM=1";
    }
    
    new_argv[new_argc] = NULL;
    
    execv(real_compiler, new_argv);
    
    // If execv returns, an error occurred
    perror("execv");
    return 1;
}
EOF

# Compile the helper
cd ios
gcc remove_g_flag.c -o remove_g_flag
chmod +x remove_g_flag

# Create compiler wrappers
mkdir -p compiler_wrappers

cat > compiler_wrappers/clang << 'EOF'
#!/bin/bash
exec "$(dirname "$0")/../remove_g_flag" /usr/bin/clang "$@"
EOF

cat > compiler_wrappers/clang++ << 'EOF'
#!/bin/bash
exec "$(dirname "$0")/../remove_g_flag" /usr/bin/clang++ "$@"
EOF

chmod +x compiler_wrappers/clang compiler_wrappers/clang++

echo "Attempting to build with modified settings..."
cd ..

# Export environment variables for the build
export PATH="$PWD/ios/compiler_wrappers:$PATH"
export FLUTTER_XCODE_ONLY_ACTIVE_ARCH=YES

# Run the build command
flutter build ios --release --no-codesign

echo "Build completed." 