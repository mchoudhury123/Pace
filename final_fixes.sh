#!/bin/bash

echo "Applying all final fixes before building..."

# 1. Fix UnknownPermissionStrategy.m
echo "Fixing UnknownPermissionStrategy.m..."
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
UNKNOWN_STRATEGY="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/UnknownPermissionStrategy.m"
UNKNOWN_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/UnknownPermissionStrategy.h"

if [ -f "$UNKNOWN_STRATEGY" ] && [ -f "$UNKNOWN_STRATEGY_H" ]; then
    sudo chmod +w "$UNKNOWN_STRATEGY" "$UNKNOWN_STRATEGY_H"
    
    # Fix the header file first
    sudo cat > "$UNKNOWN_STRATEGY_H" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

@interface UnknownPermissionStrategy : NSObject<PermissionStrategy>

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$UNKNOWN_STRATEGY" << 'EOL'
#import "UnknownPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

@implementation UnknownPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusDenied;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    
    if (completion) {
        completion(PermissionStatusDenied);
    }
}

@end
EOL
    
    sudo chmod 644 "$UNKNOWN_STRATEGY" "$UNKNOWN_STRATEGY_H"
    echo "Fixed UnknownPermissionStrategy"
fi

# 1b. Fix StoragePermissionStrategy.m
echo "Fixing StoragePermissionStrategy.m..."
STORAGE_STRATEGY="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/StoragePermissionStrategy.m"
STORAGE_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/StoragePermissionStrategy.h"

if [ -f "$STORAGE_STRATEGY" ] && [ -f "$STORAGE_STRATEGY_H" ]; then
    sudo chmod +w "$STORAGE_STRATEGY" "$STORAGE_STRATEGY_H"
    
    # Fix the header file first
    sudo cat > "$STORAGE_STRATEGY_H" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

@interface StoragePermissionStrategy : NSObject<PermissionStrategy>

+ (PermissionStatus)permissionStatus;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$STORAGE_STRATEGY" << 'EOL'
#import "StoragePermissionStrategy.h"
#import "PermissionHandlerEnums.h"

@implementation StoragePermissionStrategy

+ (PermissionStatus)permissionStatus {
    return PermissionStatusGranted;
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return [StoragePermissionStrategy permissionStatus];
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion([StoragePermissionStrategy permissionStatus]);
    }
}

@end
EOL
    
    sudo chmod 644 "$STORAGE_STRATEGY" "$STORAGE_STRATEGY_H"
    echo "Fixed StoragePermissionStrategy"
fi

# 1c. Fix SensorPermissionStrategy.m
echo "Fixing SensorPermissionStrategy.m..."
SENSOR_STRATEGY="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/SensorPermissionStrategy.m"
SENSOR_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/SensorPermissionStrategy.h"

if [ -f "$SENSOR_STRATEGY" ] && [ -f "$SENSOR_STRATEGY_H" ]; then
    sudo chmod +w "$SENSOR_STRATEGY" "$SENSOR_STRATEGY_H"
    
    # Fix the header file first - use forward declaration for CoreMotion types
    sudo cat > "$SENSOR_STRATEGY_H" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

// Forward declaration to avoid direct import of CoreMotion in header
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
@class CMMotionActivityManager;
typedef NS_ENUM(NSInteger, CMAuthorizationStatus) {
    CMAuthorizationStatusNotDetermined = 0,
    CMAuthorizationStatusRestricted,
    CMAuthorizationStatusDenied,
    CMAuthorizationStatusAuthorized
};
#endif

@interface SensorPermissionStrategy : NSObject<PermissionStrategy>

+ (PermissionStatus)permissionStatusForMotionManager;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$SENSOR_STRATEGY" << 'EOL'
#import "SensorPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

// Import CoreMotion only in implementation file
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
#import <CoreMotion/CoreMotion.h>
#endif

@implementation SensorPermissionStrategy

+ (PermissionStatus)permissionStatusForMotionManager {
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
    if (@available(iOS 11.0, *)) {
        CMAuthorizationStatus cmStatus = [CMMotionActivityManager authorizationStatus];
        
        switch (cmStatus) {
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
    
    return PermissionStatusDenied;
#else
    return PermissionStatusNotDetermined;
#endif
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return [SensorPermissionStrategy permissionStatusForMotionManager];
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
#if __has_include(<CoreMotion/CoreMotion.h>) && TARGET_OS_IOS
    if (@available(iOS 11.0, *)) {
        CMMotionActivityManager *motionManager = [[CMMotionActivityManager alloc] init];
        NSDate *today = [NSDate new];
        
        [motionManager queryActivityStartingFromDate:today
                                            toDate:today
                                           toQueue:[NSOperationQueue mainQueue]
                                       withHandler:^(NSArray * _Nullable activities, NSError * _Nullable error) {
            
            CMAuthorizationStatus cmStatus = [CMMotionActivityManager authorizationStatus];
            
            PermissionStatus permissionStatus;
            switch (cmStatus) {
                case CMAuthorizationStatusNotDetermined:
                    permissionStatus = PermissionStatusDenied;
                    break;
                case CMAuthorizationStatusRestricted:
                    permissionStatus = PermissionStatusRestricted;
                    break;
                case CMAuthorizationStatusDenied:
                    permissionStatus = PermissionStatusDenied;
                    break;
                case CMAuthorizationStatusAuthorized:
                    permissionStatus = PermissionStatusGranted;
                    break;
                default:
                    permissionStatus = PermissionStatusDenied;
                    break;
            }
            
            if (completion) {
                completion(permissionStatus);
            }
        }];
    } else {
        if (completion) {
            completion(PermissionStatusDenied);
        }
    }
#else
    if (completion) {
        completion(PermissionStatusNotDetermined);
    }
#endif
}

@end
EOL
    
    sudo chmod 644 "$SENSOR_STRATEGY" "$SENSOR_STRATEGY_H"
    echo "Fixed SensorPermissionStrategy"
fi

# 1d. Fix NotificationPermissionStrategy.m
echo "Fixing NotificationPermissionStrategy.m..."
NOTIFICATION_STRATEGY="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/NotificationPermissionStrategy.m"
NOTIFICATION_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/NotificationPermissionStrategy.h"

if [ -f "$NOTIFICATION_STRATEGY" ] && [ -f "$NOTIFICATION_STRATEGY_H" ]; then
    sudo chmod +w "$NOTIFICATION_STRATEGY" "$NOTIFICATION_STRATEGY_H"
    
    # Fix the header file first
    sudo cat > "$NOTIFICATION_STRATEGY_H" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"
#import "PermissionHandlerEnums.h"

@interface NotificationPermissionStrategy : NSObject<PermissionStrategy>

+ (PermissionStatus)permissionStatus;
+ (ServiceStatus)serviceStatus;
+ (BOOL)isAppExtension;
+ (UIApplication *)safeSharedApplication;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$NOTIFICATION_STRATEGY" << 'EOL'
#import "NotificationPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

#if PERMISSION_NOTIFICATIONS

#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>

@implementation NotificationPermissionStrategy

+ (BOOL)isAppExtension {
    return [NSBundle.mainBundle.bundlePath hasSuffix:@".appex"];
}

+ (UIApplication *)safeSharedApplication {
    if ([self isAppExtension]) {
        return nil;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication];
#pragma clang diagnostic pop
}

+ (PermissionStatus)permissionStatus {
    __block PermissionStatus permissionStatus = PermissionStatusUndetermined;
    
    if (@available(iOS 10.0, *)) {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                permissionStatus = PermissionStatusGranted;
            } else if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                permissionStatus = PermissionStatusDenied;
            } else if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined) {
                permissionStatus = PermissionStatusDenied;
            } else if (@available(iOS 12.0, *)) {
                if (settings.authorizationStatus == UNAuthorizationStatusProvisional) {
                    permissionStatus = PermissionStatusProvisional;
                }
            }
            
            dispatch_semaphore_signal(sema);
        }];
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        if (![self isAppExtension]) {
            UIUserNotificationSettings *settings = [[self safeSharedApplication] currentUserNotificationSettings];
            
            if (settings.types == UIUserNotificationTypeNone) {
                permissionStatus = PermissionStatusDenied;
            } else {
                permissionStatus = PermissionStatusGranted;
            }
        } else {
            permissionStatus = PermissionStatusUndetermined;
        }
#pragma GCC diagnostic pop
    }
    
    return permissionStatus;
}

+ (ServiceStatus)serviceStatus {
#if TARGET_OS_SIMULATOR
    return ServiceStatusNotApplicable;
#else
    if (@available(iOS 10.0, *)) {
        __block UNNotificationSettings *settings = nil;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull notificationSettings) {
            settings = notificationSettings;
            dispatch_semaphore_signal(sema);
        }];
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        
        if (@available(iOS 11.0, *)) {
            if (!settings.providesAppNotificationSettings) {
                return ServiceStatusDisabled;
            }
        }
    }
    
    return ServiceStatusEnabled;
#endif
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return [NotificationPermissionStrategy permissionStatus];
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return [NotificationPermissionStrategy serviceStatus];
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    PermissionStatus permissionStatus = [NotificationPermissionStrategy permissionStatus];
    
    if (permissionStatus != PermissionStatusDenied) {
        NSString *alertsTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"permission_handler_alerts_title"] ?: @"Alerts";
        NSString *soundsTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"permission_handler_sounds_title"] ?: @"Sounds";
        NSString *badgesTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"permission_handler_badges_title"] ?: @"Badge";
        NSString *criticalsTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"permission_handler_criticals_title"] ?: @"Critical Alerts";
        NSString *announcementsTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"permission_handler_announcements_title"] ?: @"Announcements";
        NSString *carPlayTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"permission_handler_carplay_title"] ?: @"CarPlay";
        NSString *provisionalTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"permission_handler_provisional_title"] ?: @"Provisional";
        
        NSMutableDictionary<NSString *, NSString *> *optionsTitles = [@{
            @"alert": alertsTitle,
            @"sound": soundsTitle,
            @"badge": badgesTitle,
        } mutableCopy];
        
        if (@available(iOS 12.0, *)) {
            optionsTitles[@"critical"] = criticalsTitle;
            optionsTitles[@"carPlay"] = carPlayTitle;
            optionsTitles[@"provisional"] = provisionalTitle;
        }
        
        NSArray<NSString *> *options = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"permission_handler_notification_options"] ?: @[@"alert", @"badge", @"sound"];
        
        if (@available(iOS 10.0, *)) {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            
            UNAuthorizationOptions authorizationOptions = 0;
            
            for (NSString *option in options) {
                if ([option isEqualToString:@"alert"]) {
                    authorizationOptions += UNAuthorizationOptionAlert;
                } else if ([option isEqualToString:@"badge"]) {
                    authorizationOptions += UNAuthorizationOptionBadge;
                } else if ([option isEqualToString:@"sound"]) {
                    authorizationOptions += UNAuthorizationOptionSound;
                } else if ([option isEqualToString:@"carPlay"]) {
                    if (@available(iOS 12.0, *)) {
                        authorizationOptions += UNAuthorizationOptionCarPlay;
                    }
                } else if ([option isEqualToString:@"criticalAlert"]) {
                    if (@available(iOS 12.0, *)) {
                        authorizationOptions += UNAuthorizationOptionCriticalAlert;
                    }
                } else if ([option isEqualToString:@"provisional"]) {
                    if (@available(iOS 12.0, *)) {
                        authorizationOptions += UNAuthorizationOptionProvisional;
                    }
                } else if ([option isEqualToString:@"announcement"]) {
                    if (@available(iOS 13.0, *)) {
                        authorizationOptions += UNAuthorizationOptionAnnouncement;
                    }
                }
            }
            
            [center requestAuthorizationWithOptions:authorizationOptions
                                  completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (granted && ![NotificationPermissionStrategy isAppExtension]) {
                    [self requestUserNotification];
                }
                
                if (completion) {
                    completion([NotificationPermissionStrategy permissionStatus]);
                }
            }];
        } else if (![NotificationPermissionStrategy isAppExtension]) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            UIUserNotificationType notificationTypes = 0;
            for (NSString *option in options) {
                if ([option isEqualToString:@"alert"]) {
                    notificationTypes |= UIUserNotificationTypeAlert;
                } else if ([option isEqualToString:@"badge"]) {
                    notificationTypes |= UIUserNotificationTypeBadge;
                } else if ([option isEqualToString:@"sound"]) {
                    notificationTypes |= UIUserNotificationTypeSound;
                }
            }
            
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:notificationTypes
                                                                                     categories:nil];
            
            [[NotificationPermissionStrategy safeSharedApplication] registerUserNotificationSettings:settings];
            if (completion) {
                completion([NotificationPermissionStrategy permissionStatus]);
            }
#pragma GCC diagnostic pop
        } else {
            if (completion) {
                completion(PermissionStatusUndetermined);
            }
        }
    } else {
        if (completion) {
            completion(permissionStatus);
        }
    }
}

- (void)requestUserNotification {
    if (![NotificationPermissionStrategy isAppExtension]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NotificationPermissionStrategy safeSharedApplication] registerForRemoteNotifications];
        });
    }
}

@end

#else

@implementation NotificationPermissionStrategy

+ (BOOL)isAppExtension {
    return [NSBundle.mainBundle.bundlePath hasSuffix:@".appex"];
}

+ (UIApplication *)safeSharedApplication {
    if ([self isAppExtension]) {
        return nil;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication];
#pragma clang diagnostic pop
}

+ (PermissionStatus)permissionStatus {
    return PermissionStatusUndetermined;
}

+ (ServiceStatus)serviceStatus {
    return ServiceStatusNotApplicable;
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusUndetermined;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion(PermissionStatusUndetermined);
    }
}

@end

#endif
EOL
    
    sudo chmod 644 "$NOTIFICATION_STRATEGY" "$NOTIFICATION_STRATEGY_H"
    echo "Fixed NotificationPermissionStrategy for app extension compatibility"
fi

# 1e. Fix PhotoPermissionStrategy.m
echo "Fixing PhotoPermissionStrategy.m..."
PHOTO_STRATEGY="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/PhotoPermissionStrategy.m"
PHOTO_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/PhotoPermissionStrategy.h"
ENUMS_FILE="${PERMISSION_HANDLER_PATH}/ios/Classes/PermissionHandlerEnums.h"

if [ -f "$PHOTO_STRATEGY" ] && [ -f "$ENUMS_FILE" ]; then
    # First check and fix the enum definition
    if ! grep -q "PermissionGroupLimitedPhotos" "$ENUMS_FILE"; then
        echo "Adding PermissionGroupLimitedPhotos to PermissionHandlerEnums.h"
        sudo chmod +w "$ENUMS_FILE"
        # Find the PermissionGroup enum and add LimitedPhotos if not present
        sudo awk 'BEGIN{fixed=0}
        /typedef NS_ENUM.*PermissionGroup/ {print; inEnum=1; next}
        inEnum && !fixed && /PermissionGroupPhotosAddOnly/ {print; print "    PermissionGroupLimitedPhotos,"; fixed=1; next}
        inEnum && /};/ {inEnum=0}
        {print}' "$ENUMS_FILE" > temp_enums.h
        sudo mv temp_enums.h "$ENUMS_FILE"
        sudo chmod 644 "$ENUMS_FILE"
    else
        echo "PermissionGroupLimitedPhotos already exists in PermissionHandlerEnums.h"
    fi
    
    # Now fix the PhotoPermissionStrategy.m implementation
    echo "Updating PhotoPermissionStrategy.m to handle limited photos properly"
    sudo chmod +w "$PHOTO_STRATEGY"
    sudo cat > "$PHOTO_STRATEGY" << 'EOL'
#import "PhotoPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

#if PERMISSION_PHOTOS

#import <Photos/Photos.h>

@implementation PhotoPermissionStrategy

+ (PermissionStatus)permissionStatus {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    return [PhotoPermissionStrategy determinePermissionStatus:status];
}

+ (PermissionStatus)determinePermissionStatus:(PHAuthorizationStatus)authorizationStatus {
    switch (authorizationStatus) {
        case PHAuthorizationStatusNotDetermined:
            return PermissionStatusDenied;
        case PHAuthorizationStatusRestricted:
            return PermissionStatusRestricted;
        case PHAuthorizationStatusDenied:
            return PermissionStatusPermanentlyDenied;
        case PHAuthorizationStatusAuthorized:
            return PermissionStatusGranted;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
        case PHAuthorizationStatusLimited:
            return PermissionStatusLimited;
#endif
    }
    
    return PermissionStatusDenied;
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return [PhotoPermissionStrategy permissionStatus];
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    if (permission == PermissionGroupPhotos) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus authorizationStatus) {
            PermissionStatus status = [PhotoPermissionStrategy determinePermissionStatus:authorizationStatus];
            
            if (completion) {
                completion(status);
            }
        }];
    } else if (permission == PermissionGroupPhotosAddOnly) {
        if (@available(iOS 14, *)) {
            [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly
                                                        handler:^(PHAuthorizationStatus authorizationStatus) {
                PermissionStatus status = [PhotoPermissionStrategy determinePermissionStatus:authorizationStatus];
                
                if (completion) {
                    completion(status);
                }
            }];
        } else {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus authorizationStatus) {
                PermissionStatus status = [PhotoPermissionStrategy determinePermissionStatus:authorizationStatus];
                
                if (completion) {
                    completion(status);
                }
            }];
        }
    } else if (permission == 25) { // Use a direct number instead of PermissionGroupLimitedPhotos to avoid enum issues
        if (@available(iOS 14, *)) {
            [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite
                                                        handler:^(PHAuthorizationStatus authorizationStatus) {
                PermissionStatus status = [PhotoPermissionStrategy determinePermissionStatus:authorizationStatus];
                
                if (completion) {
                    completion(status);
                }
            }];
        } else {
            if (completion) {
                completion(PermissionStatusDenied);
            }
        }
    } else {
        if (completion) {
            completion(PermissionStatusDenied);
        }
    }
}

@end

#else

@implementation PhotoPermissionStrategy

+ (PermissionStatus)permissionStatus {
    return PermissionStatusUnsupported;
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusUnsupported;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion(PermissionStatusUnsupported);
    }
}

@end

#endif
EOL
    
    sudo chmod 644 "$PHOTO_STRATEGY"
    echo "Fixed PhotoPermissionStrategy for limited photos"
fi

# 1j. Fix BackgroundRefreshStrategy.m
echo "Fixing BackgroundRefreshStrategy.m..."
BACKGROUND_STRATEGY="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/BackgroundRefreshStrategy.m"
BACKGROUND_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/BackgroundRefreshStrategy.h"

if [ -f "$BACKGROUND_STRATEGY" ] && [ -f "$BACKGROUND_STRATEGY_H" ]; then
    sudo chmod +w "$BACKGROUND_STRATEGY" "$BACKGROUND_STRATEGY_H"
    
    # Fix the header file first
    sudo cat > "$BACKGROUND_STRATEGY_H" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

@interface BackgroundRefreshStrategy : NSObject<PermissionStrategy>

+ (BOOL)isAppExtension;
+ (UIApplication *)safeSharedApplication;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$BACKGROUND_STRATEGY" << 'EOL'
#import "BackgroundRefreshStrategy.h"
#import "PermissionHandlerEnums.h"

#import <UIKit/UIKit.h>

@implementation BackgroundRefreshStrategy

+ (BOOL)isAppExtension {
    return [NSBundle.mainBundle.bundlePath hasSuffix:@".appex"];
}

+ (UIApplication *)safeSharedApplication {
    if ([self isAppExtension]) {
        return nil;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication];
#pragma clang diagnostic pop
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    if ([BackgroundRefreshStrategy isAppExtension]) {
        // App extensions can't access background refresh status
        return PermissionStatusDenied;
    }
    
    UIApplication *application = [BackgroundRefreshStrategy safeSharedApplication];
    if (!application) {
        return PermissionStatusDenied;
    }
    
    UIBackgroundRefreshStatus status = [application backgroundRefreshStatus];
    
    switch (status) {
        case UIBackgroundRefreshStatusAvailable:
            return PermissionStatusGranted;
        case UIBackgroundRefreshStatusDenied:
            return PermissionStatusDenied;
        case UIBackgroundRefreshStatusRestricted:
            return PermissionStatusRestricted;
    }
    
    return PermissionStatusDenied;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion([self checkPermissionStatus:permission]);
    }
}

@end
EOL
    
    sudo chmod 644 "$BACKGROUND_STRATEGY" "$BACKGROUND_STRATEGY_H"
    echo "Fixed BackgroundRefreshStrategy for app extension compatibility"
fi

# 2. Fix AppAuth
echo "Fixing AppAuth..."
APPAUTH_FILE="ios/Pods/AppAuth/Sources/AppAuth/iOS/OIDExternalUserAgentIOSCustomBrowser.m"
if [ -f "$APPAUTH_FILE" ]; then
    sudo chmod +w "$APPAUTH_FILE"
    sudo cat > "$APPAUTH_FILE" << 'EOL'
// This is a fixed version of OIDExternalUserAgentIOSCustomBrowser.m
// with app extension-compatible code

#import "OIDExternalUserAgentIOSCustomBrowser.h"

#if TARGET_OS_IOS || TARGET_OS_MACCATALYST

#import <UIKit/UIKit.h>

@implementation OIDExternalUserAgentIOSCustomBrowser

// Helper method to safely get sharedApplication in app extension environment
- (UIApplication *)checkExtensionContextAndReturnSharedApplication {
    if ([NSBundle.mainBundle.bundlePath hasSuffix:@".appex"]) {
        // App Extensions cannot use UIApplication.sharedApplication
        return nil;
    }
    
    // Regular app can use UIApplication.sharedApplication
    return UIApplication.sharedApplication;
}

// Helper method to safely check canOpenURL in app extension environment
- (BOOL)checkIfCanOpenURL:(NSURL *)url {
    if ([NSBundle.mainBundle.bundlePath hasSuffix:@".appex"]) {
        // App Extensions cannot check canOpenURL
        return NO;
    }
    
    // Regular app can use canOpenURL
    return [[UIApplication sharedApplication] canOpenURL:url];
}

// Helper method to safely open URLs in app extension environment
- (BOOL)openURLIfPossible:(NSURL *)url {
    if ([NSBundle.mainBundle.bundlePath hasSuffix:@".appex"]) {
        // App Extensions cannot open URLs
        return NO;
    }
    
    // Regular app can open URLs
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    return YES;
}

+ (nullable instancetype)customBrowserSafari {
  // Safari
  return [[OIDExternalUserAgentIOSCustomBrowser alloc]
      initWithURLScheme:@"https"
                   host:nil
                   path:nil];
}

+ (nullable instancetype)customBrowserChrome {
  return [[OIDExternalUserAgentIOSCustomBrowser alloc]
      initWithURLScheme:@"googlechromes"
                   host:nil
                   path:nil];
}

+ (nullable instancetype)customBrowserFirefox {
  return [[OIDExternalUserAgentIOSCustomBrowser alloc]
      initWithURLScheme:@"firefox"
                   host:nil
                   path:nil];
}

+ (nullable instancetype)customBrowserOpera {
  return [[OIDExternalUserAgentIOSCustomBrowser alloc]
      initWithURLScheme:@"opera-http"
                   host:nil
                   path:nil];
}

- (nullable instancetype)initWithURLScheme:(NSString *)URLScheme
                                      host:(nullable NSString *)host
                                      path:(nullable NSString *)path {
  self = [super init];
  if (self) {
    _URLScheme = [URLScheme copy];
    _host = [host copy];
    _path = [path copy];
  }
  return self;
}

- (BOOL)presentExternalUserAgentRequest:(nonnull id<OIDExternalUserAgentRequest>)request
                                session:(nonnull id<OIDExternalUserAgentSession>)session {
  NSURL *requestURL = [request externalUserAgentRequestURL];

  NSURL *URLToOpen = [[NSURL alloc] initWithScheme:_URLScheme
                                              host:_host
                                              path:_path ? _path : @""
                                    encodedFragment:nil];
  NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URLToOpen
                                              resolvingAgainstBaseURL:NO];

  NSString *queryItems = requestURL.query;
  if (requestURL.fragment) {
    queryItems = queryItems ? [NSString stringWithFormat:@"%@&%@", queryItems, requestURL.fragment] : requestURL.fragment;
  }

  NSString *query = [NSString stringWithFormat:@"url=%@",
                                               [[requestURL absoluteString] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
  queryItems = queryItems ? [NSString stringWithFormat:@"%@&%@", query, queryItems] : query;

  URLComponents.query = queryItems;
  URLToOpen = URLComponents.URL;

  BOOL canOpenURLs = [self checkIfCanOpenURL:URLToOpen];
  if (!canOpenURLs) {
    return NO;
  }

  _externalUserAgentFlowInProgress = YES;
  _session = session;
  [self openURLIfPossible:URLToOpen];
  return YES;
}

- (void)dismissExternalUserAgentAnimated:(BOOL)animated completion:(nonnull void (^)(void))completion {
  if (!_externalUserAgentFlowInProgress) {
    // Flow already ended
    completion();
    return;
  }
  _externalUserAgentFlowInProgress = NO;
  _session = nil;
  completion();
}

@end

#endif // TARGET_OS_IOS || TARGET_OS_MACCATALYST
EOL
    sudo chmod 644 "$APPAUTH_FILE"
    echo "Fixed AppAuth"
fi

# 3. Fix flutter_web_auth_2 if needed
echo "Fixing flutter_web_auth_2..."
FLUTTER_WEB_AUTH="${HOME}/.pub-cache/hosted/pub.dev/flutter_web_auth_2-4.1.0/ios/Classes/SwiftFlutterWebAuth2Plugin.swift"
if [ -f "$FLUTTER_WEB_AUTH" ]; then
    sudo chmod +w "$FLUTTER_WEB_AUTH"
    sudo cat > "$FLUTTER_WEB_AUTH" << 'EOL'
import AuthenticationServices
import Flutter
import SafariServices
import UIKit

public class SwiftFlutterWebAuth2Plugin: NSObject, FlutterPlugin {
    private var keepMe: Any? // Used to prevent AnyObject from being released
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth_2", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterWebAuth2Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "authenticate" {
            let arguments = call.arguments as! [String: Any]
            let url = URL(string: arguments["url"] as! String)!
            let callbackURLScheme = arguments["callbackUrlScheme"] as! String
            let preferEphemeral = arguments["preferEphemeral"] as? Bool ?? false
            
            authenticate(url: url, callbackURLScheme: callbackURLScheme, preferEphemeral: preferEphemeral, result: result)
        } else if call.method == "cleanUpDanglingCalls" {
            let arguments = call.arguments as! [String: Any]
            let errorMessage = arguments["errorMessage"] as! String
            result(FlutterError(code: "0", message: errorMessage, details: nil))
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func authenticate(url: URL, callbackURLScheme: String, preferEphemeral: Bool, result: @escaping FlutterResult) {
        if #available(iOS 12.0, *) {
            // Use ASWebAuthenticationSession
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: { (callbackURL, error) in
                if let callbackURL = callbackURL {
                    result(callbackURL.absoluteString)
                } else {
                    result(FlutterError(code: "0", message: error?.localizedDescription, details: nil))
                }
                self.keepMe = nil // Release the session
            })
            
            if #available(iOS 13.0, *) {
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = preferEphemeral
            }
            
            self.keepMe = session // Hold a reference to the session
            
            if !session.start() {
                result(FlutterError(code: "0", message: "Could not start ASWebAuthenticationSession", details: nil))
                self.keepMe = nil
            }
        } else {
            // Use SFAuthenticationSession for iOS 11
            #if os(iOS)
            if #available(iOS 11.0, *) {
                let session = SFAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: { (callbackURL, error) in
                    if let callbackURL = callbackURL {
                        result(callbackURL.absoluteString)
                    } else {
                        result(FlutterError(code: "0", message: error?.localizedDescription, details: nil))
                    }
                    self.keepMe = nil
                })
                
                self.keepMe = session
                
                if !session.start() {
                    result(FlutterError(code: "0", message: "Could not start SFAuthenticationSession", details: nil))
                    self.keepMe = nil
                }
            } else {
                // For earlier versions - fallback
                result(FlutterError(code: "0", message: "Not supported on versions earlier than iOS 11", details: nil))
            }
            #else
            result(FlutterError(code: "0", message: "Not supported on this platform", details: nil))
            #endif
        }
    }
}

// For iOS 13+
@available(iOS 13.0, *)
extension SwiftFlutterWebAuth2Plugin: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Create a dummy window as a safe default
        return UIDummyPresentationAnchor(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

// Dummy window for fallback case
private class UIDummyPresentationAnchor: UIWindow {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
EOL
    sudo chmod 644 "$FLUTTER_WEB_AUTH"
    echo "Fixed flutter_web_auth_2"
fi

# Open the Xcode project
echo "Opening Xcode workspace..."
open ios/Runner.xcworkspace

echo "All fixes have been applied. Please try building the project in Xcode."
echo "If you continue to encounter the 'PIF transfer session' error:"
echo "1. Close Xcode"
echo "2. Run the following commands:"
echo "   sudo xcode-select --reset"
echo "   sudo rm -rf ~/Library/Developer/Xcode/DerivedData"
echo "3. Restart your Mac"
echo "4. Open the project again and build"
echo ""
echo "You might also want to try this alternative approach:"
echo "1. Close Xcode"
echo "2. Delete the iOS folder entirely: rm -rf ios"
echo "3. Regenerate it with: flutter create --platforms=ios ."
echo "4. Re-run our fixes with: ./final_fixes.sh"

# 1f. Fix SpeechPermissionStrategy.h
echo "Fixing SpeechPermissionStrategy.h..."
SPEECH_STRATEGY="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/SpeechPermissionStrategy.m"
SPEECH_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/SpeechPermissionStrategy.h"

if [ -f "$SPEECH_STRATEGY_H" ]; then
    sudo chmod +w "$SPEECH_STRATEGY_H"
    
    # Fix the header file first
    sudo cat > "$SPEECH_STRATEGY_H" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

@interface SpeechPermissionStrategy : NSObject<PermissionStrategy>

@end
EOL
    
    # Create or fix the implementation file
    if [ -f "$SPEECH_STRATEGY" ]; then
        sudo chmod +w "$SPEECH_STRATEGY"
        sudo cat > "$SPEECH_STRATEGY" << 'EOL'
#import "SpeechPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

#if PERMISSION_SPEECH_RECOGNIZER

#import <Speech/Speech.h>

@implementation SpeechPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    SFSpeechRecognizerAuthorizationStatus status = [SFSpeechRecognizer authorizationStatus];
    
    switch (status) {
        case SFSpeechRecognizerAuthorizationStatusNotDetermined:
            return PermissionStatusUndetermined;
        case SFSpeechRecognizerAuthorizationStatusDenied:
            return PermissionStatusDenied;
        case SFSpeechRecognizerAuthorizationStatusRestricted:
            return PermissionStatusRestricted;
        case SFSpeechRecognizerAuthorizationStatusAuthorized:
            return PermissionStatusGranted;
    }
    
    return PermissionStatusUndetermined;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        PermissionStatus permissionStatus;
        
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                permissionStatus = PermissionStatusUndetermined;
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied:
                permissionStatus = PermissionStatusDenied;
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted:
                permissionStatus = PermissionStatusRestricted;
                break;
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
                permissionStatus = PermissionStatusGranted;
                break;
            default:
                permissionStatus = PermissionStatusUndetermined;
                break;
        }
        
        if (completion) {
            completion(permissionStatus);
        }
    }];
}

@end

#else

@implementation SpeechPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusUnsupported;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion(PermissionStatusUnsupported);
    }
}

@end

#endif
EOL
    else
        # Create the implementation file if it doesn't exist
        sudo touch "$SPEECH_STRATEGY"
        sudo chmod +w "$SPEECH_STRATEGY"
        sudo cat > "$SPEECH_STRATEGY" << 'EOL'
#import "SpeechPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

@implementation SpeechPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusUnsupported;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion(PermissionStatusUnsupported);
    }
}

@end
EOL
    fi
    
    sudo chmod 644 "$SPEECH_STRATEGY_H"
    if [ -f "$SPEECH_STRATEGY" ]; then
        sudo chmod 644 "$SPEECH_STRATEGY"
    fi
    
    echo "Fixed SpeechPermissionStrategy"
fi

# 1h. Fix EventPermissionStrategy.h
echo "Fixing EventPermissionStrategy.h..."
EVENT_STRATEGY="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/EventPermissionStrategy.m"
EVENT_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/EventPermissionStrategy.h"

if [ -f "$EVENT_STRATEGY_H" ]; then
    sudo chmod +w "$EVENT_STRATEGY_H"
    
    # Fix the header file first
    sudo cat > "$EVENT_STRATEGY_H" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

@interface EventPermissionStrategy : NSObject<PermissionStrategy>

@end
EOL
    
    # Create or fix the implementation file
    if [ -f "$EVENT_STRATEGY" ]; then
        sudo chmod +w "$EVENT_STRATEGY"
        sudo cat > "$EVENT_STRATEGY" << 'EOL'
#import "EventPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

#if PERMISSION_EVENTS

#import <EventKit/EventKit.h>

@implementation EventPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    
    switch (status) {
        case EKAuthorizationStatusNotDetermined:
            return PermissionStatusUndetermined;
        case EKAuthorizationStatusRestricted:
            return PermissionStatusRestricted;
        case EKAuthorizationStatusDenied:
            return PermissionStatusDenied;
        case EKAuthorizationStatusAuthorized:
            return PermissionStatusGranted;
    }
    
    return PermissionStatusUndetermined;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    EKEventStore *eventStore = [[EKEventStore alloc] init];
    
    [eventStore requestAccessToEntityType:EKEntityTypeEvent
                               completion:^(BOOL granted, NSError *error) {
        PermissionStatus permissionStatus = granted ? PermissionStatusGranted : PermissionStatusDenied;
        
        if (completion) {
            completion(permissionStatus);
        }
    }];
}

@end

#else

@implementation EventPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusUnsupported;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion(PermissionStatusUnsupported);
    }
}

@end

#endif
EOL
    else
        # Create the implementation file if it doesn't exist
        sudo touch "$EVENT_STRATEGY"
        sudo chmod +w "$EVENT_STRATEGY"
        sudo cat > "$EVENT_STRATEGY" << 'EOL'
#import "EventPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

@implementation EventPermissionStrategy

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusUnsupported;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion(PermissionStatusUnsupported);
    }
}

@end
EOL
    fi
    
    sudo chmod 644 "$EVENT_STRATEGY_H"
    if [ -f "$EVENT_STRATEGY" ]; then
        sudo chmod 644 "$EVENT_STRATEGY"
    fi
    
    echo "Fixed EventPermissionStrategy"
fi

# 1i. Fix LocationPermissionStrategy.m
echo "Fixing LocationPermissionStrategy.m..."
LOCATION_STRATEGY="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/LocationPermissionStrategy.m"
LOCATION_STRATEGY_H="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/LocationPermissionStrategy.h"

if [ -f "$LOCATION_STRATEGY" ] && [ -f "$LOCATION_STRATEGY_H" ]; then
    sudo chmod +w "$LOCATION_STRATEGY" "$LOCATION_STRATEGY_H"
    
    # Fix the header file first
    sudo cat > "$LOCATION_STRATEGY_H" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

@interface LocationPermissionStrategy : NSObject<PermissionStrategy>

+ (CLAuthorizationStatus)CLAuthorizationStatusForPermission:(PermissionGroup)permission;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$LOCATION_STRATEGY" << 'EOL'
#import "LocationPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

#if PERMISSION_LOCATION

#import <CoreLocation/CoreLocation.h>

@interface LocationPermissionStrategy () <CLLocationManagerDelegate>
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) PermissionStatusCallback permissionStatusHandler;
@property (strong, nonatomic) ServiceStatusCallback serviceStatusHandler;
@end

@implementation LocationPermissionStrategy

+ (CLAuthorizationStatus)CLAuthorizationStatusForPermission:(PermissionGroup)permission {
    if (@available(iOS 14.0, *)) {
        if (permission == PermissionGroupLocationWhenInUse) {
            return [CLLocationManager authorizationStatus];
        } else if (permission == PermissionGroupLocationAlways) {
            return [CLLocationManager authorizationStatus];
        }
    }
    
    return [CLLocationManager authorizationStatus];
}

- (instancetype)initWithLocationManager {
    self = [super init];
    if (self) {
        _locationManager = [CLLocationManager new];
        _locationManager.delegate = self;
    }
    
    return self;
}

- (instancetype)init {
    return [self initWithLocationManager];
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    CLAuthorizationStatus authorizationStatus = [LocationPermissionStrategy CLAuthorizationStatusForPermission:permission];

    PermissionStatus status;
    
    switch (authorizationStatus) {
        case kCLAuthorizationStatusNotDetermined:
            status = PermissionStatusUndetermined;
            break;
        case kCLAuthorizationStatusRestricted:
            status = PermissionStatusRestricted;
            break;
        case kCLAuthorizationStatusDenied:
            status = PermissionStatusDenied;
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            status = permission == PermissionGroupLocationAlways
                ? PermissionStatusDenied
                : PermissionStatusGranted;
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
            status = PermissionStatusGranted;
            break;
        default:
            status = PermissionStatusUndetermined;
            break;
    }
    
    return status;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    ServiceStatus status;
    
    // Directly creating CLLocationManager might cause crash if authorization not granted
    if ([CLLocationManager locationServicesEnabled]) {
        status = ServiceStatusEnabled;
    } else {
        status = ServiceStatusDisabled;
    }
    
    return status;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    self.permissionStatusHandler = completion;
    
    if (permission == PermissionGroupLocation) {
        permission = PermissionGroupLocationWhenInUse;
    }
    
    if (permission == PermissionGroupLocationAlways) {
        [self.locationManager requestAlwaysAuthorization];
    } else if (permission == PermissionGroupLocationWhenInUse) {
        [self.locationManager requestWhenInUseAuthorization];
    } else {
        if (completion) {
            completion(PermissionStatusUnknown);
        }
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (self.permissionStatusHandler) {
        self.permissionStatusHandler([self checkPermissionStatus:PermissionGroupLocationWhenInUse]);
        self.permissionStatusHandler = nil;
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (self.permissionStatusHandler) {
        self.permissionStatusHandler([self checkPermissionStatus:PermissionGroupLocationWhenInUse]);
        self.permissionStatusHandler = nil;
    }
}

@end

#else

@implementation LocationPermissionStrategy

+ (CLAuthorizationStatus)CLAuthorizationStatusForPermission:(PermissionGroup)permission {
    return 0;
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusUnsupported;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusNotApplicable;
}

- (void)requestPermission:(PermissionGroup)permission
              completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion(PermissionStatusUnsupported);
    }
}

@end

#endif
EOL
    
    sudo chmod 644 "$LOCATION_STRATEGY" "$LOCATION_STRATEGY_H"
    echo "Fixed LocationPermissionStrategy"
fi 