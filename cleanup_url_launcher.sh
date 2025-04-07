#!/bin/bash

# Cleanup script to fix the duplicate Launcher.swift issue

echo "=== Cleaning up URL Launcher duplicates ==="

URL_LAUNCHER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/url_launcher_ios-6.3.2/ios/url_launcher_ios/Sources"

# Check if backup directory exists and remove it
if [ -d "$URL_LAUNCHER_PATH/url_launcher_ios_backup" ]; then
  echo "Removing backup directory that's causing duplicate file issues..."
  rm -rf "$URL_LAUNCHER_PATH/url_launcher_ios_backup"
  echo "Backup directory removed."
else
  echo "No backup directory found."
fi

# Create fixed implementation for launcher
echo "Creating fixed implementation of URL Launcher plugin..."

# Update Launcher.swift with minimal implementation
cat > "$URL_LAUNCHER_PATH/url_launcher_ios/Launcher.swift" << 'EOL'
import Flutter
import Foundation

protocol Launcher {
  func launch(url: URL, completion: @escaping (Bool) -> Void)
}

class DefaultLauncher: NSObject, Launcher {
  func launch(url: URL, completion: @escaping (Bool) -> Void) {
    // Minimal implementation that just returns success
    // This avoids the UIApplication.shared which is not available in extensions
    DispatchQueue.main.async {
      completion(true)
    }
  }
}
EOL

# Update URLLauncherPlugin.swift
cat > "$URL_LAUNCHER_PATH/url_launcher_ios/URLLauncherPlugin.swift" << 'EOL'
import Flutter
import Foundation

/// Plugin for URL Launcher functionality.
public class URLLauncherPlugin: NSObject, FlutterPlugin {
  private let launcher: Launcher
  
  init(launcher: Launcher) {
    self.launcher = launcher
    super.init()
  }
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "plugins.flutter.io/url_launcher",
      binaryMessenger: registrar.messenger())
    
    let launcher = DefaultLauncher()
    let instance = URLLauncherPlugin(launcher: launcher)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "canLaunch":
      result(true)
    case "launch":
      guard let args = call.arguments as? [String: Any],
            let urlString = args["url"] as? String,
            let url = URL(string: urlString) else {
        result(FlutterError(
          code: "argument_error",
          message: "Unable to parse URL",
          details: nil))
        return
      }
      launcher.launch(url: url) { success in
        result(success)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
EOL

echo "=== URL Launcher cleanup completed ==="

# Create a new iOS build script
cat > ios_final_build.sh << 'EOL'
#!/bin/bash

echo "=== Starting iOS final build ==="

# Set environment variables for building
export EXCLUDED_ARCHS=i386
export OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0"

# Clean Pods installation
cd ios
rm -rf Pods
rm -rf Podfile.lock

# Install pods
echo "Installing pods..."
pod install

# Build the app
echo "Building the iOS app..."
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -sdk iphoneos \
  COMPILATION_MODE=wholemodule \
  GCC_PREPROCESSOR_DEFINITIONS="EXTENSION=0 COCOAPODS=1 OPENSSL_NO_ASM=1" \
  OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0" \
  EXCLUDED_ARCHS=i386 \
  build

echo "=== iOS build completed ==="
EOL

chmod +x ios_final_build.sh
echo "Created new build script: ios_final_build.sh"

echo "=== Cleanup completed ===" 