#!/bin/bash
set -e

echo "======================================================================"
echo "Comprehensive Fix Script for Flutter iOS Build"
echo "======================================================================"

# Find the exact location of the Runner.xcworkspace
cd ..
PROJECT_ROOT=$(pwd)
IOS_DIR="$PROJECT_ROOT/ios"
XCWORKSPACE_PATH=$(find "$IOS_DIR" -name "Runner.xcworkspace" 2>/dev/null)

if [ -z "$XCWORKSPACE_PATH" ]; then
  echo "Error: Runner.xcworkspace not found in $IOS_DIR"
  echo "Searching in subdirectories..."
  XCWORKSPACE_PATH=$(find "$PROJECT_ROOT" -name "Runner.xcworkspace" 2>/dev/null)
  
  if [ -z "$XCWORKSPACE_PATH" ]; then
    echo "Error: Runner.xcworkspace not found in project"
    exit 1
  fi
fi

WORKSPACE_DIR=$(dirname "$XCWORKSPACE_PATH")
echo "Found Runner.xcworkspace at: $XCWORKSPACE_PATH"
echo "Workspace directory: $WORKSPACE_DIR"

# Update URL launcher plugin Swift files
echo "Step 1: Updating URL launcher plugin Swift files"
URL_LAUNCHER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/url_launcher_ios-6.3.2/ios/url_launcher_ios/Sources/url_launcher_ios"
LAUNCHER_SWIFT="${URL_LAUNCHER_PATH}/Launcher.swift"
PLUGIN_SWIFT="${URL_LAUNCHER_PATH}/URLLauncherPlugin.swift"
SESSION_SWIFT="${URL_LAUNCHER_PATH}/URLLaunchSession.swift"

echo "Checking plugin paths..."
echo "LAUNCHER_SWIFT: $LAUNCHER_SWIFT"
echo "PLUGIN_SWIFT: $PLUGIN_SWIFT"
echo "SESSION_SWIFT: $SESSION_SWIFT"

if [ ! -f "$LAUNCHER_SWIFT" ] || [ ! -f "$PLUGIN_SWIFT" ]; then
  echo "Error: URL launcher plugin Swift files not found at the expected paths."
  echo "Looking for URL launcher plugin files..."
  find ~/.pub-cache -name "Launcher.swift" | grep url_launcher
  find ~/.pub-cache -name "URLLauncherPlugin.swift" | grep url_launcher
  
  # Try to find the correct version
  URL_LAUNCHER_DIR=$(find ~/.pub-cache -path "*/url_launcher_ios*/ios/url_launcher_ios/Sources/url_launcher_ios" 2>/dev/null | head -n 1)
  if [ -n "$URL_LAUNCHER_DIR" ]; then
    URL_LAUNCHER_PATH="$URL_LAUNCHER_DIR"
    LAUNCHER_SWIFT="${URL_LAUNCHER_PATH}/Launcher.swift"
    PLUGIN_SWIFT="${URL_LAUNCHER_PATH}/URLLauncherPlugin.swift"
    SESSION_SWIFT="${URL_LAUNCHER_PATH}/URLLaunchSession.swift"
    
    echo "Found alternative paths:"
    echo "LAUNCHER_SWIFT: $LAUNCHER_SWIFT"
    echo "PLUGIN_SWIFT: $PLUGIN_SWIFT"
    echo "SESSION_SWIFT: $SESSION_SWIFT"
  else
    echo "Error: Could not find URL launcher plugin files."
    exit 1
  fi
fi

# Create backups
echo "Creating backups of original Swift files..."
cp "$LAUNCHER_SWIFT" "${LAUNCHER_SWIFT}.bak"
cp "$PLUGIN_SWIFT" "${PLUGIN_SWIFT}.bak"
[ -f "$SESSION_SWIFT" ] && cp "$SESSION_SWIFT" "${SESSION_SWIFT}.bak"

# Replace the Launcher.swift file
echo "Updating Launcher.swift..."
cat > "$LAUNCHER_SWIFT" << 'EOF'
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import SafariServices

/// A handler for URL launching functionality.
protocol UrlLauncher {
  /// Opens a URL.
  func launch(url: URL, withViewController viewController: UIViewController? = nil, result: @escaping (Bool?, FlutterError?) -> Void)
}

/// The default URL launcher implementation.
class Launcher: UrlLauncher {
  func launch(url: URL, withViewController viewController: UIViewController? = nil, result: @escaping (Bool?, FlutterError?) -> Void) {
    // For iOS 13+, use view controller approach when possible
    if #available(iOS 13.0, *), let viewController = viewController, url.scheme?.hasPrefix("http") == true {
      let safariVC = SFSafariViewController(url: url)
      viewController.present(safariVC, animated: true) {
        result(true, nil)
      }
    } else {
      #if EXTENSION
      result(false, FlutterError(code: "ACTIVITY_NOT_AVAILABLE",
                               message: "NOT_AVAILABLE",
                               details: nil))
      #else
      UIApplication.shared.open(url) { success in
        result(success, nil)
      }
      #endif
    }
  }
}
EOF

# Update URLLauncherPlugin.swift
echo "Updating URLLauncherPlugin.swift..."
cat > "$PLUGIN_SWIFT" << 'EOF'
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Flutter
import UIKit

/// A plugin to open URLs.
public class URLLauncherPlugin: NSObject, FlutterPlugin, URLLauncherApi {
  // The launcher instance is used for testing, to verify that the URL was launched.
  let launcher: UrlLauncher
  let flutterViewController: UIViewController?

  /// Creates an instance that holds the Flutter view controller.
  /// - Parameter flutterViewController: The Flutter view controller, or `nil` when not available.
  public init(flutterViewController: UIViewController? = nil) {
    self.flutterViewController = flutterViewController
    launcher = Launcher()
  }

  /// Registers a plugin with the given registrar.
  /// - Parameter registrar: The registrar to apply to the plugin.
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if !EXTENSION
    // Only initialize the plugin instance if the current device can open URLs.
    let messenger = registrar.messenger()
    let api = URLLauncherPlugin()
    let viewController = registrar.messenger().wrapperViewController
    setUpURLLauncherApi(messenger, api, api.flutterViewController ?? viewController)
    #endif
  }

  /// Whether the system can handle a URL with the specified scheme.
  /// - Parameter scheme: The scheme to check.
  /// - Parameter result: The resulting callback.
  public func canLaunchURL(_ scheme: String, result: @escaping (Bool?, FlutterError?) -> Void) {
    #if EXTENSION
    result(false, FlutterError(code: "ACTIVITY_NOT_AVAILABLE",
                             message: "NOT_AVAILABLE",
                             details: nil))
    #else
    result(UIApplication.shared.canOpenURL(URL(string: scheme)!), nil)
    #endif
  }

  /// Opens a URL handled by the system.
  /// - Parameter url: The URL to open.
  /// - Parameter result: The resulting callback.
  public func launchURL(_ url: String, result: @escaping (Bool?, FlutterError?) -> Void) {
    let parsedURL = URL(string: url)
    guard let url = parsedURL else {
      result(FlutterError(code: "argument_error", message: "Unable to parse URL", details: nil))
      return
    }
    
    // Get the root view controller if available
    var rootViewController: UIViewController?
    if #available(iOS 13.0, *) {
      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         let window = scene.windows.first {
        rootViewController = window.rootViewController
      }
    } else {
      rootViewController = UIApplication.shared.keyWindow?.rootViewController
    }
    
    launcher.launch(url: url, withViewController: rootViewController ?? flutterViewController, result: result)
  }
}
EOF

# Update URLLaunchSession.swift if it exists
if [ -f "$SESSION_SWIFT" ]; then
  echo "Updating URLLaunchSession.swift..."
  cat > "$SESSION_SWIFT" << 'EOF'
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Flutter
import UIKit

/// Handles the launch session for a given URL.
public class URLLaunchSession: NSObject {
  var completed = false
}

/// A session callback handler for universal links.
public class SessionCallbackHandler: NSObject {
  var callbackHandlers = [String: URLLaunchSession]()
}
EOF
fi

# Step 2: Add EXTENSION=0 to all XCConfig files
echo "Step 2: Adding EXTENSION=0 preprocessor definition to XCConfig files"
find "$IOS_DIR" -name "*.xcconfig" -exec sed -i '' 's/GCC_PREPROCESSOR_DEFINITIONS = \$(inherited)/GCC_PREPROCESSOR_DEFINITIONS = $(inherited) EXTENSION=0/g' {} \;
find "$IOS_DIR/Flutter" -name "*.xcconfig" -exec sed -i '' 's/GCC_PREPROCESSOR_DEFINITIONS = \$(inherited)/GCC_PREPROCESSOR_DEFINITIONS = $(inherited) EXTENSION=0/g' {} \;

# Step 3: Clean and rebuild the project
echo "Step 3: Clean and rebuild the project"
cd "$WORKSPACE_DIR"
rm -rf Pods Podfile.lock
pod install

# Step 4: Build the app
echo "Step 4: Building the app"
xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -sdk iphoneos \
    -arch arm64 \
    COMPILATION_MODE=wholemodule \
    COMPILER_INDEX_STORE_ENABLE=NO \
    GCC_PREPROCESSOR_DEFINITIONS='EXTENSION=0 COCOAPODS=1 OPENSSL_NO_ASM=1' \
    EXCLUDED_ARCHS=i386 \
    OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0" \
    WARNING_CFLAGS="-w" \
    clean build

echo "======================================================================"
echo "Build process completed!"
echo "Check the output above for any errors."
echo "======================================================================" 