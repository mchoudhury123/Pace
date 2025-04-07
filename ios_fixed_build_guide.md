# iOS Build Guide with All Fixes Applied

## Fixed Issues

1. **UIApplication.shared Reference Issue**
   - Fixed the reference in `SwiftFlutterWebAuth2Plugin.swift` to make it fully app extension compatible
   - Created a backup of the original file
   - Implemented a completely UIApplication.shared-free approach using a custom presentation anchor

2. **Permission Handler Issues**
   - Fixed `PhonePermissionStrategy.m` implementation
   - Fixed `BackgroundRefreshStrategy.m` implementation
   - Fixed `SensorPermissionStrategy.m` implementation

3. **Podfile Integration**
   - Updated Flutter xcconfig files to include the Pods configuration
   - Fixed missing xcfilelist files
   - Set bundle identifier to `com.mfchoudhury.fundracerapp`

## Building the App in Xcode

1. **Verify Configuration**
   - Open Xcode and select the `Runner` project
   - Go to the "Signing & Capabilities" tab
   - Ensure the Bundle Identifier is set to `com.mfchoudhury.fundracerapp`
   - Sign in with your Apple ID in the "Team" dropdown
   - Make sure "Automatically manage signing" is checked

2. **Select Target Device**
   - Connect your physical iOS device or select a simulator
   - Choose the device from the device selector in Xcode's toolbar

3. **Build and Run**
   - Click the Run button (▶️) in Xcode
   - If you encounter errors, check the Issues navigator in Xcode for details

## Troubleshooting

If you encounter persistent errors:

1. **Clean Build Folder**
   - In Xcode, go to Product > Clean Build Folder
   
2. **Fix Specific Permission Issues**
   - Run the individual fix scripts as needed:
     ```
     ./fix_flutter_web_auth.sh
     ./fix_web_auth_extension_safe.sh  # Use this for UIApplication.shared errors
     ./fix_permission_handler_errors.sh
     ```

3. **Reset All Build Files**
   - Run the comprehensive reset script:
     ```
     ./reset_ios_build.sh
     ```

4. **Fix Podfile Integration**
   - Run the Podfile integration fix script:
     ```
     ./fix_podfile_integration.sh
     ```

## For Release Builds

To prepare a release build:

1. Update the version in `pubspec.yaml`
2. Set the build configuration to "Release" in Xcode
3. Archive the app (Product > Archive)
4. Follow the App Store Connect submission process

## All Scripts

- `fix_flutter_web_auth.sh` - Fixes the basic flutter_web_auth_2 plugin issues
- `fix_web_auth_shared_reference.sh` - Fixes the UIApplication.shared error (standard app version)
- `fix_web_auth_extension_safe.sh` - Fixes the UIApplication.shared error (fully extension-compatible)
- `fix_permission_handler_errors.sh` - Fixes permission handler implementation issues
- `fix_podfile_integration.sh` - Fixes Podfile integration with Flutter config
- `fix_background_refresh_strategy.sh` - Fixes background refresh permission implementation
- `reset_ios_build.sh` - Performs a deep clean of iOS build environment
- `final_ios_build.sh` - Runs all fixes and builds the app 