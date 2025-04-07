#!/bin/bash
set -e

echo "Starting plugin fix script..."

# Define paths to plugins
URL_LAUNCHER_DIR="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/url_launcher_ios-6.3.2"
PERMISSION_HANDLER_DIR="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"

# Create directory for backup files
echo "Creating backup directory..."
mkdir -p backups

# Fix URL Launcher plugin
if [ -d "$URL_LAUNCHER_DIR" ]; then
  echo "Found url_launcher_ios plugin at: $URL_LAUNCHER_DIR"
  
  URL_LAUNCHER_PLUGIN="$URL_LAUNCHER_DIR/ios/url_launcher_ios/Sources/url_launcher_ios/URLLauncherPlugin.swift"
  LAUNCHER_SWIFT="$URL_LAUNCHER_DIR/ios/url_launcher_ios/Sources/url_launcher_ios/Launcher.swift"
  
  if [ -f "$URL_LAUNCHER_PLUGIN" ] && [ -f "$LAUNCHER_SWIFT" ]; then
    echo "Found Swift files:"
    echo "  - $URL_LAUNCHER_PLUGIN"
    echo "  - $LAUNCHER_SWIFT"
    
    # Backup original files
    cp "$URL_LAUNCHER_PLUGIN" "backups/URLLauncherPlugin.swift.orig"
    cp "$LAUNCHER_SWIFT" "backups/Launcher.swift.orig"
    
    echo "Modifying URLLauncherPlugin.swift..."
    cat > "$URL_LAUNCHER_PLUGIN" << 'EOF'
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Flutter
import UIKit

/// A plugin for launching URLs.
public class URLLauncherPlugin: NSObject, FlutterPlugin {
  /// Registers this plugin.
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(name: "plugins.flutter.io/url_launcher", binaryMessenger: messenger)
    
    let instance = URLLauncherPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  /// Handles method calls from the Flutter framework.
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let urlLauncher = URLLaunchSession()
    switch call.method {
    case "canLaunchUrl":
      guard let arguments = call.arguments as? [String: Any],
            let urlString = arguments["url"] as? String else {
        result(FlutterError(code: "argument_error",
                           message: "Arguments missing url",
                           details: nil))
        return
      }
      
      #if !EXTENSION
      let canLaunch: Bool
      if let url = URL(string: urlString) {
        canLaunch = UIApplication.shared.canOpenURL(url)
      } else {
        canLaunch = false
      }
      result(canLaunch)
      #else
      // Cannot use UIApplication.shared in app extension
      result(false)
      #endif
      
    case "launchUrl":
      guard let arguments = call.arguments as? [String: Any],
            let urlString = arguments["url"] as? String,
            let url = URL(string: urlString) else {
        result(FlutterError(code: "argument_error",
                           message: "Arguments missing url or invalid url",
                           details: nil))
        return
      }
      
      #if !EXTENSION
      let universalLinksOnly = (arguments["universalLinksOnly"] as? Bool) ?? false
      
      if #available(iOS 10.0, *) {
        let options = [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: universalLinksOnly]
        UIApplication.shared.open(url, options: options) { success in
          result(success)
        }
      } else {
        result(UIApplication.shared.openURL(url))
      }
      #else
      // Cannot use UIApplication.shared in app extension
      result(false)
      #endif
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
EOF
    
    echo "Modifying Launcher.swift..."
    cat > "$LAUNCHER_SWIFT" << 'EOF'
// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation
import UIKit

/// A class that provides URL launching functionality.
class Launcher {
  /// Opens a given URL.
  ///
  /// - Parameters:
  ///   - url: The URL to open.
  func launchURL(_ url: NSURL) -> Bool {
    #if !EXTENSION
    return UIApplication.shared.openURL(url as URL)
    #else
    // Cannot use UIApplication.shared in app extension
    return false
    #endif
  }
}
EOF
    
    echo "Successfully updated url_launcher_ios plugin files"
  else
    echo "Could not find Swift files in url_launcher_ios plugin"
  fi
else
  echo "Could not find url_launcher_ios plugin"
fi

# Fix Permission Handler plugin
if [ -d "$PERMISSION_HANDLER_DIR" ]; then
  echo "Found permission_handler_apple plugin at: $PERMISSION_HANDLER_DIR"
  
  PHONE_PERMISSION="$PERMISSION_HANDLER_DIR/ios/Classes/strategies/PhonePermissionStrategy.m"
  NOTIFICATION_PERMISSION="$PERMISSION_HANDLER_DIR/ios/Classes/strategies/NotificationPermissionStrategy.m"
  
  if [ -f "$PHONE_PERMISSION" ] && [ -f "$NOTIFICATION_PERMISSION" ]; then
    echo "Found Objective-C files:"
    echo "  - $PHONE_PERMISSION"
    echo "  - $NOTIFICATION_PERMISSION"
    
    # Backup original files
    cp "$PHONE_PERMISSION" "backups/PhonePermissionStrategy.m.orig"
    cp "$NOTIFICATION_PERMISSION" "backups/NotificationPermissionStrategy.m.orig"
    
    echo "Modifying PhonePermissionStrategy.m..."
    awk '{
      if ($0 ~ /\[\[UIApplication sharedApplication\] canOpenURL/) {
        print "#if !EXTENSION";
        print $0;
        print "#else";
        print "    if (FALSE) {";
        print "#endif";
      } else {
        print $0;
      }
    }' "backups/PhonePermissionStrategy.m.orig" > "$PHONE_PERMISSION"
    
    echo "Modifying NotificationPermissionStrategy.m..."
    awk '{
      if ($0 ~ /\[\[UIApplication sharedApplication\] registerUserNotificationSettings/) {
        print "#if !EXTENSION";
        print $0;
        print "#else";
        print "  // Cannot register notification settings in app extension";
        print "#endif";
      } else {
        print $0;
      }
    }' "backups/NotificationPermissionStrategy.m.orig" > "$NOTIFICATION_PERMISSION"
    
    echo "Successfully updated permission_handler_apple plugin files"
  else
    echo "Could not find Objective-C files in permission_handler_apple plugin"
  fi
else
  echo "Could not find permission_handler_apple plugin"
fi

# Update Podfile to compile with EXTENSION=0 preprocessor definition
echo "Updating Podfile to include EXTENSION=0 preprocessor definition..."
cat > ios/Podfile << 'EOF'
# Uncomment this line to define a global platform for your project
platform :ios, '14.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
          '$(inherited)',
          # Fix for BoringSSL-GRPC -G flag issue
          'COCOAPODS=1',
          # Add a definition to conditionally compile code for app extensions
          'EXTENSION=0'
        ]
        
        # Fix for BoringSSL-GRPC -G flag issue
        if target.name == 'BoringSSL-GRPC'
          config.build_settings['OTHER_CFLAGS'] = config.build_settings['OTHER_CFLAGS'].map { |flag| 
            if flag == '-G' || flag == '-GCC_WARN_INHIBIT_ALL_WARNINGS'
              nil # Remove these flags
            else
              flag
            end
          }.compact
        end
        
        # Make all iOS deployment targets consistent
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
        
        # Allow for some missing architectures on simulators
        config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      end
    end
  end
end
EOF

# Create direct build script
echo "Creating direct build script..."
cat > direct_build.sh << 'EOF'
#!/bin/bash
set -e

echo "Cleaning and rebuilding iOS project..."
cd ios
rm -rf Pods
rm -rf .symlinks
flutter clean
flutter pub get
pod install --verbose

echo "Running direct Xcode build..."
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

echo "Direct Xcode build completed!"
echo "You can find the built app at: ios/build/DerivedData/Build/Products/Release-iphoneos/Runner.app"
cd ..
EOF
chmod +x direct_build.sh

echo "Plugin fix script completed. Now run ./direct_build.sh to build the app." 