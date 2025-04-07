#!/bin/bash

echo "Fixing AppAuth library's use of sharedApplication..."

# Path to the AppAuth file with issues
TARGET_FILE="/Users/mohammedchoudhury/fundracer_app_new/ios/Pods/AppAuth/Sources/AppAuth/iOS/OIDExternalUserAgentIOSCustomBrowser.m"

# Check if the file exists
if [ -f "$TARGET_FILE" ]; then
    # Create backup with timestamp
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    sudo cp "$TARGET_FILE" "${TARGET_FILE}.backup_${TIMESTAMP}"
    echo "Created backup with timestamp ${TIMESTAMP}"
    
    # Make sure we have write permissions
    sudo chmod +w "$TARGET_FILE"
    
    # Create a temporary file with the fixes - we'll add an isAppExtension check similar to what we did for permission_handler
    sudo cat > "${TARGET_FILE}.tmp" << 'EOL'
/*! @file OIDExternalUserAgentIOSCustomBrowser.m
    @brief AppAuth iOS SDK
    @copyright
        Copyright 2016 Google Inc. All Rights Reserved.
    @copydetails
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
 */

#import "OIDExternalUserAgentIOSCustomBrowser.h"

#import <UIKit/UIKit.h>

#import "OIDErrorUtilities.h"
#import "OIDURLQueryComponent.h"

NS_ASSUME_NONNULL_BEGIN

@implementation OIDExternalUserAgentIOSCustomBrowser {
  NSString *_URLScheme;
  OIDExternalUserAgentIOSCustomBrowserType _browserType;
  NSURL *_openURL;
}

+ (nullable instancetype)CustomBrowserChromeiOS {
  return [[self alloc] initWithBrowserType:OIDExternalUserAgentIOSCustomBrowserTypeChrome
                                 URLScheme:@"googlechrome-x-callback:"];
}

+ (nullable instancetype)CustomBrowserFirefoxiOS {
  return [[self alloc] initWithBrowserType:OIDExternalUserAgentIOSCustomBrowserTypeFirefox
                                 URLScheme:@"firefox:"];
}

+ (nullable instancetype)CustomBrowserSafariiOS {
  return [[self alloc] initWithBrowserType:OIDExternalUserAgentIOSCustomBrowserTypeSafari
                                 URLScheme:@""];
}

+ (nullable instancetype)CustomBrowserOperaiOS {
  return [[self alloc] initWithBrowserType:OIDExternalUserAgentIOSCustomBrowserTypeOpera
                                 URLScheme:@"opera-http:"];
}

+ (nullable instancetype)CustomBrowserOperaTouch {
  return [[self alloc] initWithBrowserType:OIDExternalUserAgentIOSCustomBrowserTypeOperaTouch
                                 URLScheme:@"opera-touch-http:"];
}

+ (nullable instancetype)CustomBrowserSafariViewController {
  return [[self alloc] initWithBrowserType:OIDExternalUserAgentIOSCustomBrowserTypeSafariViewController
                                 URLScheme:@""];
}

+ (nullable instancetype)CustomBrowserASWebAuthenticationSession {
  return [[self alloc] initWithBrowserType:OIDExternalUserAgentIOSCustomBrowserTypeASWebAuthenticationSession
                                 URLScheme:@""];
}

+ (nullable instancetype)CustomBrowserSFAuthenticationSession {
  return [[self alloc] initWithBrowserType:OIDExternalUserAgentIOSCustomBrowserTypeSFAuthenticationSession
                                 URLScheme:@""];
}

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

- (nullable instancetype)initWithBrowserType:(OIDExternalUserAgentIOSCustomBrowserType)browserType
                                   URLScheme:(NSString *)URLScheme {
  self = [super init];
  if (self) {
    _URLScheme = [URLScheme copy];
    _browserType = browserType;
    // Verify Browser is installed.
    if (![self verifyBrowser]) {
      return nil;
    }
  }
  return self;
}

- (BOOL)verifyBrowser {
  UIApplication *application = [OIDExternalUserAgentIOSCustomBrowser safeSharedApplication];
  if (!application) {
      return NO;
  }
  
  NSURL *testURL;
  switch (_browserType) {
    case OIDExternalUserAgentIOSCustomBrowserTypeChrome: {
      testURL = [NSURL URLWithString:@"googlechrome-x-callback://test"];
      break;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeFirefox: {
      testURL = [NSURL URLWithString:@"firefox://test"];
      break;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeSafari: {
      // Safari is always available on iOS.
      return YES;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeSafariViewController: {
      // SafariViewController is available on iOS 9+.
      if (@available(iOS 9.0, *)) {
        return YES;
      }
      return NO;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeASWebAuthenticationSession: {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 120000
      // ASWebAuthenticationSession was available on iOS 11 but only reliable on iOS 12+.
      if (@available(iOS 12.0, *)) {
        return YES;
      }
#endif // __IPHONE_OS_VERSION_MAX_ALLOWED >= 120000
      return NO;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeSFAuthenticationSession: {
      // SFAuthenticationSession is available on iOS 11+, but it is deprecated in iOS 12.
      // Note: we use this over ASWebAuthenticationSession on iOS 11 which has the same API 
      // but isn't as reliable.
      if (@available(iOS 11.0, *)) {
        // SFAuthenticationSession is deprecated in iOS 12
        if (@available(iOS 12.0, *)) {
          return NO;
        }
        return YES;
      }
      return NO;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeOpera: {
      testURL = [NSURL URLWithString:@"opera-http://test"];
      break;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeOperaTouch: {
      testURL = [NSURL URLWithString:@"opera-touch-http://test"];
      break;
    }
  }
  BOOL canOpenURLTest = [application canOpenURL:testURL];
  return canOpenURLTest;
}

- (BOOL)presentExternalUserAgentRequest:(id<OIDExternalUserAgentRequest>)request
                                session:(id<OIDExternalUserAgentSession>)session {
  _session = session;
  NSURL *requestURL = [request externalUserAgentRequestURL];
  UIApplication *application = [OIDExternalUserAgentIOSCustomBrowser safeSharedApplication];
  if (!application) {
      return NO;
  }
  
  NSURL *openURL = [self openURL:requestURL];
  _openURL = openURL;
  BOOL openedURL = [application openURL:openURL];
  if (!openedURL) {
    [self cleanUp];
    NSError *safariError = [OIDErrorUtilities errorWithCode:OIDErrorCodeSafariOpenError
                             underlyingError:nil
                                 description:@"Unable to open Safari."];
    [session failExternalUserAgentFlowWithError:safariError];
  }
  return openedURL;
}

- (NSURL *)openURL:(NSURL *)requestURL {
  if (_browserType == OIDExternalUserAgentIOSCustomBrowserTypeSafariViewController ||
      _browserType == OIDExternalUserAgentIOSCustomBrowserTypeASWebAuthenticationSession ||
      _browserType == OIDExternalUserAgentIOSCustomBrowserTypeSFAuthenticationSession) {
    // These are handled by the view controller, so no need to create special URLs.
    return requestURL;
  }
  NSURLComponents *components;
  switch (_browserType) {
    case OIDExternalUserAgentIOSCustomBrowserTypeChrome: {
      components = [[NSURLComponents alloc] initWithString:_URLScheme];
      [components setPath:@"//x-callback-url/open"];
      NSMutableArray<NSURLQueryItem *> *queryItems = [@[
        [NSURLQueryItem queryItemWithName:@"url" value:requestURL.absoluteString],
      ] mutableCopy];
      [components setQueryItems:queryItems];
      break;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeFirefox: {
      // See documentation on the custom URL scheme:
      // https://github.com/mozilla-mobile/firefox-ios/wiki/URL-Schemes
      components = [[NSURLComponents alloc] initWithURL:requestURL resolvingAgainstBaseURL:NO];
      [components setScheme:_URLScheme];
      break;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeSafari: {
      // Safari is able to open all http:// and https:// URLs.
      components = [[NSURLComponents alloc] initWithURL:requestURL resolvingAgainstBaseURL:NO];
      break;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeOpera: {
      // See documentation on the custom URL scheme:
      // https://dev.opera.com/extensions/continental-app.html
      if ([requestURL.scheme isEqualToString:@"http"]) {
        components = [[NSURLComponents alloc] initWithURL:requestURL resolvingAgainstBaseURL:NO];
        [components setScheme:_URLScheme];
      } else if ([requestURL.scheme isEqualToString:@"https"]) {
        components = [[NSURLComponents alloc] initWithURL:requestURL resolvingAgainstBaseURL:NO];
        [components setScheme:[_URLScheme stringByReplacingOccurrencesOfString:@"http" withString:@"https"]];
      } else {
        NSAssert(NO, @"Request URL must be http or https");
      }
      break;
    }
    case OIDExternalUserAgentIOSCustomBrowserTypeOperaTouch: {
      // Opera Touch doesn't seem to have documentation in this custom scheme. But it works the same way. 
      if ([requestURL.scheme isEqualToString:@"http"]) {
        components = [[NSURLComponents alloc] initWithURL:requestURL resolvingAgainstBaseURL:NO];
        [components setScheme:_URLScheme];
      } else if ([requestURL.scheme isEqualToString:@"https"]) {
        components = [[NSURLComponents alloc] initWithURL:requestURL resolvingAgainstBaseURL:NO];
        [components setScheme:[_URLScheme stringByReplacingOccurrencesOfString:@"http" withString:@"https"]];
      } else {
        NSAssert(NO, @"Request URL must be http or https");
      }
      break;
    }
    default: {
      NSAssert(NO, @"NSAssert(NO, @'Other types handled above')");
    }
  }
  return components.URL;
}

- (void)dismissExternalUserAgentAnimated:(BOOL)animated completion:(void (^)(void))completion {
  if (!_session) {
    // Ignore this call if there is no active session.
    if (completion) completion();
    return;
  }
  
  // Close the Chrome custom tab.
  if (_browserType == OIDExternalUserAgentIOSCustomBrowserTypeChrome) {
    UIApplication *application = [OIDExternalUserAgentIOSCustomBrowser safeSharedApplication];
    if (application) {
        [application openURL:[NSURL URLWithString:@"googlechrome-x-callback://close-all-tabs"]];
    }
  }
  
  [self cleanUp];
  if (completion) completion();
}

- (void)cleanUp {
  _session = nil;
  _openURL = nil;
}

@end

NS_ASSUME_NONNULL_END
EOL
    
    # Replace the original file with our fixed version
    sudo mv "${TARGET_FILE}.tmp" "$TARGET_FILE"
    
    # Make sure the file permissions are correct
    sudo chmod 644 "$TARGET_FILE"
    
    echo "Fixed AppAuth library with proper UIApplication.sharedApplication handling"
else
    echo "Error: AppAuth file not found at $TARGET_FILE"
    exit 1
fi

echo "AppAuth sharedApplication fix completed!" 