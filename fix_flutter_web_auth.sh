#!/bin/bash

echo "Starting flutter_web_auth_2 fixes..."

# Set paths
WEB_AUTH_PATH="/Users/mohammedchoudhury/.pub-cache/hosted/pub.dev/flutter_web_auth_2-4.1.0"
SWIFT_FILE="${WEB_AUTH_PATH}/ios/Classes/SwiftFlutterWebAuth2Plugin.swift"

# Create a fresh backup of the original file
if [ -f "${SWIFT_FILE}" ]; then
    cp "${SWIFT_FILE}" "${SWIFT_FILE}.original"
    echo "Created backup at ${SWIFT_FILE}.original"
    
    # Replace the file with a fixed implementation
    cat > "${SWIFT_FILE}" << 'EOL'
import Flutter
import UIKit
import AuthenticationServices

public class SwiftFlutterWebAuth2Plugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth_2", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterWebAuth2Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "authenticate" else {
            result(FlutterMethodNotImplemented)
            return
        }
        
        let args = call.arguments as! [String: Any]
        let url = URL(string: args["url"] as! String)!
        let callbackURLScheme = args["callbackUrlScheme"] as! String
        let preferEphemeral = (args["preferEphemeral"] as? Bool) ?? false
        
        // Get the rootViewController safely without using UIApplication.shared
        // This approach uses the key window's rootViewController
        var rootViewController: UIViewController?
        if #available(iOS 13.0, *) {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            rootViewController = scene?.windows.first?.rootViewController
        } else {
            let keyWindow = UIApplication.shared.windows.first { $0.isKeyWindow }
            rootViewController = keyWindow?.rootViewController
        }
        
        guard let presentingViewController = rootViewController else {
            result(FlutterError(code: "FAILED", message: "Failed to obtain root view controller", details: nil))
            return
        }
        
        authenticate(url: url, callbackURLScheme: callbackURLScheme, preferEphemeral: preferEphemeral, presentingViewController: presentingViewController, completion: { response in
            result(response)
        })
    }
    
    private func authenticate(url: URL, callbackURLScheme: String, preferEphemeral: Bool, presentingViewController: UIViewController, completion: @escaping (Any?) -> Void) {
        if #available(iOS 13.0, *) {
            // iOS 13+ implementation using ASWebAuthenticationSession
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackURLScheme
            ) { (callbackURL, error) in
                guard error == nil, let callbackURL = callbackURL else {
                    completion(FlutterError(code: "CANCELED", message: error?.localizedDescription ?? "Unknown error", details: nil))
                    return
                }
                completion(callbackURL.absoluteString)
            }
            
            // Use strong reference to the context provider to prevent deallocation
            let contextProvider = WebAuthenticationPresentationContextProvider(presentingViewController: presentingViewController)
            // Store context provider as an associated object to keep it alive
            objc_setAssociatedObject(session, &AssociatedObjectHandle, contextProvider, .OBJC_ASSOCIATION_RETAIN)
            
            // Set the presentation context provider
            session.presentationContextProvider = contextProvider
            
            // Set the prefersEphemeralWebBrowserSession
            session.prefersEphemeralWebBrowserSession = preferEphemeral
            
            // Start the auth session
            session.start()
        } else {
            // Fallback for iOS 12 and below
            completion(FlutterError(code: "FAILED", message: "This plugin requires iOS 13 or higher", details: nil))
        }
    }
}

// A variable to use as a handle for the associated object
private var AssociatedObjectHandle: UInt8 = 0

@available(iOS 13.0, *)
class WebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let presentingViewController: UIViewController
    
    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        super.init()
    }
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return presentingViewController.view.window ?? ASPresentationAnchor()
    }
}
EOL
    
    echo "Updated SwiftFlutterWebAuth2Plugin.swift with fixed implementation"
else
    echo "ERROR: SwiftFlutterWebAuth2Plugin.swift not found at ${SWIFT_FILE}"
fi

echo "flutter_web_auth_2 fixes completed." 