#!/bin/bash

echo "Cleaning up backup files..."

# Permission handler backups
PERMISSION_HANDLER_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/permission_handler_apple-9.4.6"
rm -f ${PERMISSION_HANDLER_PATH}/ios/Classes/strategies/*.backup*

# Flutter web auth backups
WEB_AUTH_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/flutter_web_auth_2-4.1.0"
rm -f ${WEB_AUTH_PATH}/ios/Classes/*.backup*

echo "All backup files cleaned up." 