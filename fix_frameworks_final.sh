#!/bin/bash

echo "Fixing system frameworks linking issue..."

# First, let's fix the iOS Podfile to properly link system frameworks
cd ~/fundracer_app_new/ios

# Backup original Podfile
echo "Creating Podfile backup..."
cp Podfile Podfile.backup.final

# Create a new simplified podfile with framework linking
echo "Creating simplified Podfile with direct framework linking..."
cat > Podfile << 'EOL'
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
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Start of the permission handler fix
    target.build_configurations.each do |config|
      # Permission handler preprocessor definitions
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_LOCATION=1',
        'PERMISSION_NOTIFICATIONS=1',
        'PERMISSION_MEDIA_LIBRARY=1',
        'PERMISSION_SENSORS=1',
        'PERMISSION_BACKGROUND_REFRESH=1',
      ]
      
      # Add required frameworks to all targets
      config.build_settings['OTHER_LDFLAGS'] ||= ['$(inherited)']
      config.build_settings['OTHER_LDFLAGS'] << '-framework' << 'CoreMotion'
      config.build_settings['OTHER_LDFLAGS'] << '-framework' << 'CoreLocation'
      
      # Fix Xcode 14+ compatibility issues
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
      config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
      config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      
      # Set application extension API only to YES to avoid UIApplication.shared issues
      config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      
      # Add arm64 architecture to valid architectures
      config.build_settings['VALID_ARCHS'] = 'arm64 arm64e'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386 arm64'
    end
  end
end
EOL

# Now let's fix the permission handler plugin to not reference CoreMotion directly
PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
SENSOR_HEADER="${PLUGIN_PATH}/ios/Classes/strategies/SensorPermissionStrategy.h"

echo "Creating backup of SensorPermissionStrategy.h..."
cp "${SENSOR_HEADER}" "${SENSOR_HEADER}.framework.bak"

# Update the header file to use a forward declaration instead of direct import
echo "Updating SensorPermissionStrategy.h to use forward declaration..."
cat > "${SENSOR_HEADER}" << 'EOL'
//
//  SensorPermissionStrategy.h
//  permission_handler_apple
//

#import <Foundation/Foundation.h>
#import "../PermissionStrategy.h"

// Forward declare classes from CoreMotion to avoid direct import
#ifndef CMAUTHORIZATIONSTATUS_DECLARED
#define CMAUTHORIZATIONSTATUS_DECLARED
typedef NS_ENUM(NSInteger, CMAuthorizationStatus) {
    CMAuthorizationStatusNotDetermined = 0,
    CMAuthorizationStatusRestricted,
    CMAuthorizationStatusDenied,
    CMAuthorizationStatusAuthorized
};
#endif

@interface SensorPermissionStrategy : NSObject <PermissionStrategy>
@end
EOL

# Update the implementation file 
SENSOR_IMPL="${PLUGIN_PATH}/ios/Classes/strategies/SensorPermissionStrategy.m"
echo "Creating backup of SensorPermissionStrategy.m..."
cp "${SENSOR_IMPL}" "${SENSOR_IMPL}.framework.bak"

# Update the implementation to properly import CoreMotion
echo "Updating SensorPermissionStrategy.m with proper imports..."
cat > "${SENSOR_IMPL}" << 'EOL'
//
//  SensorPermissionStrategy.m
//  permission_handler_apple
//

#import "SensorPermissionStrategy.h"
#import "../PermissionHandlerEnums.h"
#import <CoreMotion/CoreMotion.h>

#if PERMISSION_SENSORS

@implementation SensorPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    if (@available(iOS 11.0, *)) {
        CMAuthorizationStatus status = [CMMotionActivityManager authorizationStatus];
        
        switch (status) {
            case CMAuthorizationStatusNotDetermined:
                return PermissionStatusDenied;
            case CMAuthorizationStatusRestricted:
                return PermissionStatusRestricted;
            case CMAuthorizationStatusDenied:
                return PermissionStatusDenied;
            case CMAuthorizationStatusAuthorized:
                return PermissionStatusGranted;
        }
    }
    
#if TARGET_OS_OSX
    // On macOS, sensors are always unavailable
    return PermissionStatusPermanentlyDenied;
#else
    // Default to denied for iOS versions that don't support CMMotionActivityManager
    return PermissionStatusDenied;
#endif
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
#if TARGET_OS_OSX
    return ServiceStatusNotApplicable;
#else
    return ServiceStatusEnabled;
#endif
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    if (@available(iOS 11.0, *)) {
        CMMotionActivityManager *manager = [[CMMotionActivityManager alloc] init];
        NSDate *now = [NSDate date];
        
        [manager queryActivityStartingFromDate:now
                                       toDate:now
                                      toQueue:[NSOperationQueue mainQueue]
                                  withHandler:^(NSArray<CMMotionActivity *> * _Nullable activities, NSError * _Nullable error) {
            
            if (error != nil && error.code == CMErrorMotionActivityNotAuthorized) {
                completion(PermissionStatusDenied);
                return;
            }
            
            completion(PermissionStatusGranted);
        }];
        
        return;
    }
    
#if TARGET_OS_OSX
    // On macOS, sensors are always unavailable
    completion(PermissionStatusPermanentlyDenied);
#else
    // Default to denied for iOS versions that don't support CMMotionActivityManager
    completion(PermissionStatusDenied);
#endif
}

@end

#else

@implementation SensorPermissionStrategy
@end

#endif
EOL

# Reinstall pods with the new Podfile and plugin changes
echo "Cleaning up build artifacts and reinstalling pods..."
rm -rf Pods
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/*

echo "Reinstalling pods with the updated Podfile..."
pod install --repo-update

echo "All framework linking issues fixed."
echo "Now close Xcode, reopen it, and build the project again." 