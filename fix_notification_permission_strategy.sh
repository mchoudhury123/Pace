#!/bin/bash

echo "Fixing NotificationPermissionStrategy.m issues..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
STRATEGY_DIR="${PERMISSION_HANDLER_PATH}/ios/Classes/strategies"
TARGET_FILE="${STRATEGY_DIR}/NotificationPermissionStrategy.m"
HEADER_FILE="${STRATEGY_DIR}/NotificationPermissionStrategy.h"

# Check if the files exist
if [ -f "$TARGET_FILE" ] && [ -f "$HEADER_FILE" ]; then
    # Create backup with timestamp to avoid overwriting existing backups
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    sudo cp "$TARGET_FILE" "${TARGET_FILE}.backup_${TIMESTAMP}"
    sudo cp "$HEADER_FILE" "${HEADER_FILE}.backup_${TIMESTAMP}"
    echo "Created backups with timestamp ${TIMESTAMP}"
    
    # Make sure we have write permissions
    sudo chmod +w "$TARGET_FILE" "$HEADER_FILE"
    
    # Fix the header file first
    sudo cat > "$HEADER_FILE" << 'EOL'
#import <Foundation/Foundation.h>
#import "PermissionStrategy.h"

@interface NotificationPermissionStrategy : NSObject<PermissionStrategy>

+ (PermissionStatus)permissionStatus;
+ (ServiceStatus)serviceStatus;

@end
EOL
    
    # Fix the implementation file
    sudo cat > "$TARGET_FILE" << 'EOL'
#import "NotificationPermissionStrategy.h"
#import "PermissionHandlerEnums.h"

#if PERMISSION_NOTIFICATIONS

#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>

@implementation NotificationPermissionStrategy

+ (PermissionStatus)permissionStatus {
    __block PermissionStatus permissionStatus = PermissionStatusUnknown;
    
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
        UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        
        if (settings.types == UIUserNotificationTypeNone) {
            permissionStatus = PermissionStatusDenied;
        } else {
            permissionStatus = PermissionStatusGranted;
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
                if (granted) {
                    [self requestUserNotification];
                }
                
                if (completion) {
                    completion([NotificationPermissionStrategy permissionStatus]);
                }
            }];
        } else {
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
            
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
            if (completion) {
                completion([NotificationPermissionStrategy permissionStatus]);
            }
#pragma GCC diagnostic pop
        }
    } else {
        if (completion) {
            completion(permissionStatus);
        }
    }
}

- (void)requestUserNotification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    });
}

@end

#else

@implementation NotificationPermissionStrategy

+ (PermissionStatus)permissionStatus {
    return PermissionStatusUnknown;
}

+ (ServiceStatus)serviceStatus {
    return ServiceStatusUnknown;
}

- (PermissionStatus)checkPermissionStatus:(PermissionGroup)permission {
    return PermissionStatusUnknown;
}

- (ServiceStatus)checkServiceStatus:(PermissionGroup)permission {
    return ServiceStatusUnknown;
}

- (void)requestPermission:(PermissionGroup)permission
               completion:(PermissionStatusCallback)completion {
    if (completion) {
        completion(PermissionStatusUnknown);
    }
}

@end

#endif
EOL
    
    # Make sure the file permissions are correct
    sudo chmod 644 "$TARGET_FILE" "$HEADER_FILE"
    
    echo "Fixed NotificationPermissionStrategy files"
    echo "Header file contents:"
    cat "$HEADER_FILE"
else
    echo "Error: One or more required files not found!"
    [ ! -f "$TARGET_FILE" ] && echo "Missing: $TARGET_FILE"
    [ ! -f "$HEADER_FILE" ] && echo "Missing: $HEADER_FILE"
    exit 1
fi

echo "NotificationPermissionStrategy fix completed!" 