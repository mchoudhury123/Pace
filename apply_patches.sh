#!/bin/bash
set -e

# Find the URL launcher plugin location
LAUNCHER_DIR=$(find ~/.pub-cache/hosted/pub.dev -name url_launcher_ios -type d | head -n 1)
if [ -n "$LAUNCHER_DIR" ]; then
  echo "Found url_launcher_ios plugin at: $LAUNCHER_DIR"
  
  # Backup original files
  cp "$LAUNCHER_DIR/ios/Classes/URLLauncherPlugin.swift" "$LAUNCHER_DIR/ios/Classes/URLLauncherPlugin.swift.orig"
  cp "$LAUNCHER_DIR/ios/Classes/Launcher.swift" "$LAUNCHER_DIR/ios/Classes/Launcher.swift.orig"
  
  # Apply patches
  patch -u "$LAUNCHER_DIR/ios/Classes/Launcher.swift" -i "$(pwd)/patches/url_launcher_ios_Launcher.swift.patch"
  patch -u "$LAUNCHER_DIR/ios/Classes/URLLauncherPlugin.swift" -i "$(pwd)/patches/url_launcher_ios_URLLauncherPlugin.swift.patch"
  
  echo "Successfully patched url_launcher_ios plugin"
else
  echo "Could not find url_launcher_ios plugin"
fi

# Find the permission handler plugin location
PERMISSION_DIR=$(find ~/.pub-cache/hosted/pub.dev -name permission_handler_apple -type d | head -n 1)
if [ -n "$PERMISSION_DIR" ]; then
  echo "Found permission_handler_apple plugin at: $PERMISSION_DIR"
  
  # Backup original files
  cp "$PERMISSION_DIR/ios/Classes/strategies/PhonePermissionStrategy.m" "$PERMISSION_DIR/ios/Classes/strategies/PhonePermissionStrategy.m.orig"
  cp "$PERMISSION_DIR/ios/Classes/strategies/NotificationPermissionStrategy.m" "$PERMISSION_DIR/ios/Classes/strategies/NotificationPermissionStrategy.m.orig"
  
  # Apply patches
  patch -u "$PERMISSION_DIR/ios/Classes/strategies/PhonePermissionStrategy.m" -i "$(pwd)/patches/permission_handler_PhonePermissionStrategy.m.patch"
  patch -u "$PERMISSION_DIR/ios/Classes/strategies/NotificationPermissionStrategy.m" -i "$(pwd)/patches/permission_handler_NotificationPermissionStrategy.m.patch"
  
  echo "Successfully patched permission_handler_apple plugin"
else
  echo "Could not find permission_handler_apple plugin"
fi
