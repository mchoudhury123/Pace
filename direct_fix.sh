#!/bin/bash

echo "======================================================================"
echo "Direct Fix Script for Flutter iOS Build"
echo "======================================================================"

# Update URL launcher plugin Swift files directly
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
  exit 1
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

echo "Step 2: Creating build script with EXTENSION=0 flag"
cat > "ios_build.sh" << 'EOF'
#!/bin/bash

cd ios
# Clean and reinstall pods
rm -rf Pods Podfile.lock
pod install

# Build with xcodebuild
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
EOF

# Make the build script executable
chmod +x ios_build.sh

echo "======================================================================"
echo "URL launcher plugin fixed successfully!"
echo "To build the app, run: ./ios_build.sh"
echo "======================================================================" 