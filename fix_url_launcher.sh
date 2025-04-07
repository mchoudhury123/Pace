#!/bin/bash

echo "Creating patches directory..."
mkdir -p Patches/url_launcher_ios

echo "Patching URL launcher iOS plugin..."

# Create patch for URLLauncherPlugin.swift
cat > Patches/url_launcher_ios/URLLauncherPlugin.swift.patch << 'EOF'
--- URLLauncherPlugin.swift.orig   2024-03-26 18:46:47
+++ URLLauncherPlugin.swift        2024-03-26 18:47:15
@@ -52,10 +52,20 @@
   // MARK: - FLTURLLauncherApi

   public func launchURL(_ url: String, result: @escaping (Bool?, FlutterError?) -> Void) {
-    guard let url = URL(string: url) else {
+    let nsurl = URL(string: url)
+    guard let url = nsurl else {
       result(FlutterError(code: "argument_error", message: "Unable to parse URL", details: nil))
       return
     }
+    
+    // For iOS 13+, use UIApplication.shared with a check first
+    #if !EXTENSION
+    if #available(iOS 13.0, *) {
+      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
+         let rootViewController = scene.windows.first?.rootViewController {
+        delegate.launcher.launch(url: url, withViewController: rootViewController, result: result)
+        return
+      }
+    }
     delegate.launcher.launch(url: url, result: result)
+    #endif
   }
EOF

# Create patch for Launcher.swift
cat > Patches/url_launcher_ios/Launcher.swift.patch << 'EOF'
--- Launcher.swift.orig   2024-03-26 18:46:47
+++ Launcher.swift        2024-03-26 18:47:15
@@ -5,14 +5,36 @@
 import Foundation
 import SafariServices
 
+#if !EXTENSION
 /// A handler for URL launching functionality.
 protocol UrlLauncher {
   /// Opens a URL.
-  func launch(url: URL, result: @escaping (Bool?, FlutterError?) -> Void)
+  func launch(url: URL, withViewController viewController: UIViewController? = nil, result: @escaping (Bool?, FlutterError?) -> Void)
 }
 
 /// The default URL launcher implementation.
 class Launcher: UrlLauncher {
-  func launch(url: URL, result: @escaping (Bool?, FlutterError?) -> Void) {
-    UIApplication.shared.open(url) { success in result(success, nil) }
+  func launch(url: URL, withViewController viewController: UIViewController? = nil, result: @escaping (Bool?, FlutterError?) -> Void) {
+    // For iOS 13+, check if UIApplication.shared is available
+    if #available(iOS 13.0, *) {
+      if let viewController = viewController {
+        // Use the view controller-based approach when possible
+        if url.scheme == "http" || url.scheme == "https" {
+          let safariVC = SFSafariViewController(url: url)
+          viewController.present(safariVC, animated: true) {
+            result(true, nil)
+          }
+        } else {
+          UIApplication.shared.open(url) { success in
+            result(success, nil)
+          }
+        }
+      } else {
+        UIApplication.shared.open(url) { success in
+          result(success, nil)
+        }
+      }
+    } else {
+      UIApplication.shared.open(url) { success in result(success, nil) }
+    }
   }
+}
+#endif
EOF

# Now apply the patches
echo "Applying patches to URL launcher iOS plugin..."

# The correct paths based on the find command
LAUNCHER_SWIFT="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/url_launcher_ios-6.3.2/ios/url_launcher_ios/Sources/url_launcher_ios/Launcher.swift"
PLUGIN_SWIFT="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/url_launcher_ios-6.3.2/ios/url_launcher_ios/Sources/url_launcher_ios/URLLauncherPlugin.swift"

if [ -f "$LAUNCHER_SWIFT" ] && [ -f "$PLUGIN_SWIFT" ]; then
  # Make backups first
  cp "$LAUNCHER_SWIFT" "${LAUNCHER_SWIFT}.orig"
  cp "$PLUGIN_SWIFT" "${PLUGIN_SWIFT}.orig"
  
  # Apply the patches
  patch "$LAUNCHER_SWIFT" < Patches/url_launcher_ios/Launcher.swift.patch
  patch "$PLUGIN_SWIFT" < Patches/url_launcher_ios/URLLauncherPlugin.swift.patch
  
  echo "Patches applied successfully"
else
  echo "Could not find Swift files to patch at the specified paths"
  echo "LAUNCHER_SWIFT: $LAUNCHER_SWIFT"
  echo "PLUGIN_SWIFT: $PLUGIN_SWIFT"
  exit 1
fi

echo "URL launcher iOS plugin patched successfully" 