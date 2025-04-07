#!/bin/bash

echo "Fixing UIApplication.shared reference in flutter_web_auth_2 plugin for app extensions..."

PLUGIN_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/flutter_web_auth_2-4.1.0"
SWIFT_FILE="${PLUGIN_PATH}/ios/Classes/SwiftFlutterWebAuth2Plugin.swift"

# Create backup
echo "Creating backup of the original file..."
cp "${SWIFT_FILE}" "${SWIFT_FILE}.extension_bak"

# Replace the problematic code with a completely extension-safe version
echo "Updating the plugin implementation with app extension compatible code..."
cat > "${SWIFT_FILE}" << 'EOL'
import AuthenticationServices
import Flutter
import UIKit
import SafariServices
import WebKit

public class SwiftFlutterWebAuth2Plugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth_2", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterWebAuth2Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    private var authSession: Any?
    private var window: UIWindow?
    private var flutterViewController: UIViewController?
    
    private func cleanUp() {
        if let authSession = authSession as? ASWebAuthenticationSession {
            authSession.cancel()
        }
        if let authSession = authSession as? SFAuthenticationSession {
            authSession.cancel()
        }
        if let authSession = authSession as? SFSafariViewController {
            authSession.dismiss(animated: true)
        }
        authSession = nil
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "authenticate" {
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String,
                  let callbackUrlScheme = args["callbackUrlScheme"] as? String
            else {
                result(FlutterError(code: "INVALID_ARGS", message: "Arguments are missing", details: nil))
                return
            }
            
            let preferEphemeral = args["preferEphemeral"] as? Bool ?? false
            
            cleanUp()
            
            if #available(iOS 13.0, *) {
                let authSession = ASWebAuthenticationSession(
                    url: URL(string: url)!,
                    callbackURLScheme: callbackUrlScheme
                ) { [weak self] callbackURL, error in
                    guard let self = self else { return }
                    
                    guard error == nil, let callbackURL = callbackURL else {
                        if let error = error as NSError? {
                            if error.domain == ASWebAuthenticationSessionErrorDomain &&
                                error.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                                result(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                            } else {
                                result(FlutterError(code: "EUNKNOWN", message: error.localizedDescription, details: nil))
                            }
                        } else {
                            result(FlutterError(code: "EUNKNOWN", message: "An unknown error occurred", details: nil))
                        }
                        return
                    }
                    
                    result(callbackURL.absoluteString)
                    self.cleanUp()
                }
                
                // Get the presentation context for the authentication session
                if #available(iOS 13.0, *) {
                    authSession.presentationContextProvider = self
                }
                
                authSession.prefersEphemeralWebBrowserSession = preferEphemeral
                
                if !authSession.start() {
                    result(FlutterError(code: "EUNKNOWN", message: "Failed to start ASWebAuthenticationSession", details: nil))
                }
                
                self.authSession = authSession
            } else {
                // Fallback for earlier iOS versions (11-12)
                let authSession = SFAuthenticationSession(
                    url: URL(string: url)!,
                    callbackURLScheme: callbackUrlScheme
                ) { callbackURL, error in
                    guard error == nil, let callbackURL = callbackURL else {
                        if let error = error as NSError? {
                            result(FlutterError(code: "EUNKNOWN", message: error.localizedDescription, details: nil))
                        } else {
                            result(FlutterError(code: "EUNKNOWN", message: "An unknown error occurred", details: nil))
                        }
                        return
                    }
                    
                    result(callbackURL.absoluteString)
                    self.cleanUp()
                }
                
                if !authSession.start() {
                    result(FlutterError(code: "EUNKNOWN", message: "Failed to start SFAuthenticationSession", details: nil))
                }
                
                self.authSession = authSession
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}

// iOS 13+ presentation context provider
@available(iOS 13.0, *)
extension SwiftFlutterWebAuth2Plugin: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Create a new window for presentation if we're in an app extension
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.windowLevel = UIWindow.Level.normal
        window.makeKeyAndVisible()
        self.window = window
        return window
    }
}
EOL

echo "Fix completed for UIApplication.shared reference in flutter_web_auth_2 plugin."
echo "Now you should rebuild your app in Xcode." 