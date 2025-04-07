#!/bin/bash

echo "Fixing flutter_web_auth_2 UIApplication.shared references for app extensions..."

FLUTTER_WEB_AUTH="${HOME}/.pub-cache/hosted/pub.dev/flutter_web_auth_2-4.1.0/ios/Classes/SwiftFlutterWebAuth2Plugin.swift"

if [ -f "$FLUTTER_WEB_AUTH" ]; then
    # Create backup
    sudo cp "$FLUTTER_WEB_AUTH" "${FLUTTER_WEB_AUTH}.extension.backup"
    echo "Created backup at ${FLUTTER_WEB_AUTH}.extension.backup"
    
    # Fix the file
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
    echo "Fixed flutter_web_auth_2 UIApplication.shared references for app extensions"
else
    echo "Error: Flutter Web Auth 2 plugin file not found at $FLUTTER_WEB_AUTH"
    exit 1
fi

echo "Flutter Web Auth 2 plugin app extension fix completed!" 