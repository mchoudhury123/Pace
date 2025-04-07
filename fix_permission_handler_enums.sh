#!/bin/bash

echo "Fixing PermissionHandlerEnums.h to prevent redefinition issues..."

# Path to permission_handler_apple plugin
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
TARGET_FILE="${PERMISSION_HANDLER_PATH}/ios/Classes/PermissionHandlerEnums.h"

# Check if the file exists
if [ -f "$TARGET_FILE" ]; then
    # Create backup with timestamp
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    sudo cp "$TARGET_FILE" "${TARGET_FILE}.backup_${TIMESTAMP}"
    echo "Created backup with timestamp ${TIMESTAMP}"
    
    # Make sure we have write permissions
    sudo chmod +w "$TARGET_FILE"
    
    # Add safeguards against redefinition by adding proper include guards
    sudo cat > "$TARGET_FILE" << 'EOL'
//
//  PermissionHandlerEnums.h
//  permission_handler_apple
//

#ifndef PermissionHandlerEnums_h
#define PermissionHandlerEnums_h

#ifndef PermissionGroup
typedef NS_ENUM(int, PermissionGroup) {
    PermissionGroupCalendar = 0,
    PermissionGroupCamera,
    PermissionGroupContacts,
    PermissionGroupLocation,
    PermissionGroupLocationAlways,
    PermissionGroupLocationWhenInUse,
    PermissionGroupMediaLibrary,
    PermissionGroupMicrophone,
    PermissionGroupPhone,
    PermissionGroupPhotos,
    PermissionGroupPhotosAddOnly,
    PermissionGroupLimitedPhotos,
    PermissionGroupReminders,
    PermissionGroupSensors,
    PermissionGroupSms,
    PermissionGroupSpeech,
    PermissionGroupStorage,
    PermissionGroupIgnoreBatteryOptimizations,
    PermissionGroupNotification,
    PermissionGroupAccessMediaLocation,
    PermissionGroupActivityRecognition,
    PermissionGroupUnknown,
    PermissionGroupBluetooth,
    PermissionGroupManageExternalStorage,
    PermissionGroupSystemAlertWindow,
    PermissionGroupRequestInstallPackages,
    PermissionGroupAppTrackingTransparency,
    PermissionGroupCriticalAlerts,
    PermissionGroupAccessNotificationPolicy,
    PermissionGroupBluetoothScan,
    PermissionGroupBluetoothAdvertise,
    PermissionGroupBluetoothConnect,
    PermissionGroupNearbyWifiDevices,
    PermissionGroupVideos,
    PermissionGroupAudio,
    PermissionGroupScheduleExactAlarm,
    PermissionGroupCalendarFullAccess,
    PermissionGroupAssistant,
    PermissionGroupBackgroundRefresh,
};
#endif

#ifndef PermissionStatus
typedef NS_ENUM(int, PermissionStatus) {
    PermissionStatusDenied = 0,
    PermissionStatusGranted,
    PermissionStatusRestricted,
    PermissionStatusLimited,
    PermissionStatusPermanentlyDenied,
    PermissionStatusProvisional,
};
#endif

#ifndef ServiceStatus
typedef NS_ENUM(int, ServiceStatus) {
    ServiceStatusDisabled = 0,
    ServiceStatusEnabled,
    ServiceStatusNotApplicable,
};
#endif

#ifndef PermissionStatusCallback
typedef void (^PermissionStatusCallback)(PermissionStatus permissionStatus);
#endif

#ifndef ServiceStatusCallback
typedef void (^ServiceStatusCallback)(ServiceStatus serviceStatus);
#endif

#endif /* PermissionHandlerEnums_h */
EOL
    
    # Make sure the file permissions are correct
    sudo chmod 644 "$TARGET_FILE"
    
    echo "Fixed PermissionHandlerEnums.h with proper include guards"
else
    echo "Error: PermissionHandlerEnums.h not found at $TARGET_FILE"
    exit 1
fi

echo "PermissionHandlerEnums.h fix completed!" 