#!/bin/bash

echo "Modifying URL launcher iOS plugin directly..."

# The correct paths based on the find command
LAUNCHER_SWIFT="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/url_launcher_ios-6.3.2/ios/url_launcher_ios/Sources/url_launcher_ios/Launcher.swift"
PLUGIN_SWIFT="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/url_launcher_ios-6.3.2/ios/url_launcher_ios/Sources/url_launcher_ios/URLLauncherPlugin.swift"

if [ -f "$LAUNCHER_SWIFT" ] && [ -f "$PLUGIN_SWIFT" ]; then
  # Make backups first
  cp "$LAUNCHER_SWIFT" "${LAUNCHER_SWIFT}.orig"
  cp "$PLUGIN_SWIFT" "${PLUGIN_SWIFT}.orig"
  
  # Replace the Launcher.swift file with our modified version
  cat > "$LAUNCHER_SWIFT" << 'EOF'
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import SafariServices

#if !EXTENSION
/// A handler for URL launching functionality.
protocol UrlLauncher {
  /// Opens a URL.
  func launch(url: URL, withViewController viewController: UIViewController? = nil, result: @escaping (Bool?, FlutterError?) -> Void)
}

/// The default URL launcher implementation.
class Launcher: UrlLauncher {
  func launch(url: URL, withViewController viewController: UIViewController? = nil, result: @escaping (Bool?, FlutterError?) -> Void) {
    // For iOS 13+, check if UIApplication.shared is available
    if #available(iOS 13.0, *) {
      if let viewController = viewController {
        // Use the view controller-based approach when possible
        if url.scheme == "http" || url.scheme == "https" {
          let safariVC = SFSafariViewController(url: url)
          viewController.present(safariVC, animated: true) {
            result(true, nil)
          }
        } else {
          UIApplication.shared.open(url) { success in
            result(success, nil)
          }
        }
      } else {
        UIApplication.shared.open(url) { success in
          result(success, nil)
        }
      }
    } else {
      UIApplication.shared.open(url) { success in result(success, nil) }
    }
  }
}
#endif
EOF

  # Replace the URLLauncherPlugin.swift file with our modified version
  # First, read the original file to preserve most of it
  ORIGINAL_CONTENT=$(cat "$PLUGIN_SWIFT")
  
  # Find the launchURL method and replace it
  MODIFIED_CONTENT=$(echo "$ORIGINAL_CONTENT" | sed -E '
    /public func launchURL.*result: @escaping.*{/,/^  }/c\
  public func launchURL(_ url: String, result: @escaping (Bool?, FlutterError?) -> Void) {\
    let nsurl = URL(string: url)\
    guard let url = nsurl else {\
      result(FlutterError(code: "argument_error", message: "Unable to parse URL", details: nil))\
      return\
    }\
    \
    // For iOS 13+, use UIApplication.shared with a check first\
    #if !EXTENSION\
    if #available(iOS 13.0, *) {\
      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,\
         let rootViewController = scene.windows.first?.rootViewController {\
        delegate.launcher.launch(url: url, withViewController: rootViewController, result: result)\
        return\
      }\
    }\
    delegate.launcher.launch(url: url, result: result)\
    #endif\
  }
  ')
  
  echo "$MODIFIED_CONTENT" > "$PLUGIN_SWIFT"
  
  echo "Swift files modified successfully"
else
  echo "Could not find Swift files to modify at the specified paths"
  echo "LAUNCHER_SWIFT: $LAUNCHER_SWIFT"
  echo "PLUGIN_SWIFT: $PLUGIN_SWIFT"
  exit 1
fi

echo "URL launcher iOS plugin modified successfully"

# Now add a preprocessor definition to the project
echo "Adding EXTENSION=0 preprocessor definition to XCConfig files..."

# Find all xcconfig files and add EXTENSION=0 definition
find ../Flutter -name "*.xcconfig" -exec sed -i '' 's/GCC_PREPROCESSOR_DEFINITIONS = \$(inherited)/GCC_PREPROCESSOR_DEFINITIONS = $(inherited) EXTENSION=0/g' {} \;

echo "Preprocessor definitions updated"

# Create script for final build
cat > final_build.sh << 'EOF'
#!/bin/bash

# Setup environment variables to fix BoringSSL -G issue
export EXCLUDED_ARCHS=i386
export OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0"
export WARNING_CFLAGS="-w"

# Clean pods
echo "Cleaning and reinstalling pods..."
rm -rf Pods Podfile.lock
cd ..
flutter clean
flutter pub get
cd ios
pod install

# Build the app with Xcode 
echo "Building app with fixed settings..."
xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -sdk iphoneos \
    -arch arm64 \
    COMPILATION_MODE=wholemodule \
    COMPILER_INDEX_STORE_ENABLE=NO \
    GCC_PREPROCESSOR_DEFINITIONS='EXTENSION=0 COCOAPODS=1 OPENSSL_NO_ASM=1' \
    EXCLUDED_ARCHS=i386 \
    build || {
      echo "Build failed. Check Xcode logs for details."
      exit 1
    }

echo "Build completed! The app can be found at: build/Release-iphoneos/Runner.app"
EOF

chmod +x final_build.sh
echo "Created final_build.sh script - run it to complete the build process" 