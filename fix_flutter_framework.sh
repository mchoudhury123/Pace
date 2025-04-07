#!/bin/bash

# Exit on error
set -e

echo "Fixing Flutter framework issues..."

# Step 1: Clean up
echo "Cleaning up previous build artifacts..."
flutter clean
rm -rf ios/Pods ios/Podfile.lock
find . -name "COCOAPODS" -type f -delete

# Step 2: Setup Flutter framework
echo "Setting up Flutter framework..."
flutter precache --ios
flutter pub get

# Step 3: Create a proper Flutter framework structure 
echo "Creating Flutter framework structure..."
mkdir -p ios/Flutter/Flutter.framework/Headers
echo "#import <Foundation/Foundation.h>" > ios/Flutter/Flutter.framework/Headers/Flutter.h
echo "export * from \"./Headers/Flutter.h\"" > ios/Flutter/Flutter.framework/Flutter

# Step 4: Update the Podfile
echo "Updating Podfile..."
cat > ios/Podfile << 'EOL'
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
  
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      # Remove COCOAPODS file after installation if it exists
      cocoapods_file = File.join(installer.sandbox.root, "COCOAPODS")
      File.delete(cocoapods_file) if File.exist?(cocoapods_file)
      
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
        config.build_settings['SWIFT_COMPILATION_MODE'] = 'Incremental'
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
          '$(inherited)',
          'EXTENSION=0',
        ]
        
        # Ensure Flutter.framework is found correctly
        config.build_settings['FRAMEWORK_SEARCH_PATHS'] = [
          '$(inherited)',
          '${PODS_ROOT}/../Flutter',
          '${PODS_CONFIGURATION_BUILD_DIR}'
        ]
        
        # Fix other header search paths
        config.build_settings['HEADER_SEARCH_PATHS'] = [
          '$(inherited)',
          '${PODS_ROOT}/Headers/Public',
          '${PODS_CONFIGURATION_BUILD_DIR}/**',
          '${PODS_ROOT}/../Flutter'
        ]
      end
    end
    
    # Fix for URL launcher
    url_launcher_path = File.join(installer.sandbox.root, 'url_launcher_ios')
    if Dir.exist?(url_launcher_path)
      swift_files = Dir.glob(File.join(url_launcher_path, '**', '*.swift'))
      swift_files.each do |file|
        content = File.read(file)
        if content.include?('if #available(iOS 10.0, *)') && !content.include?('#if EXTENSION')
          new_content = content.gsub('if #available(iOS 10.0, *)', '#if EXTENSION\n#else\nif #available(iOS 10.0, *)')
          new_content = new_content.gsub(/application\.open.*\}/m) do |match|
            match + "\n#endif"
          end
          File.write(file, new_content)
        end
      end
    end
    
    # Ensure no COCOAPODS files remain
    Dir.glob(File.join(installer.sandbox.root, "**", "COCOAPODS")).each do |file|
      File.delete(file) if File.exist?(file)
    end
  end
end
EOL

# Step 5: Install pods
echo "Installing pods..."
cd ios && pod install

# Step 6: Update the scheme file to avoid script errors
echo "Updating Runner.xcscheme..."
cat > ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme << 'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1510"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "97C146ED1CF9000F007C117D"
               BuildableName = "Runner.app"
               BlueprintName = "Runner"
               ReferencedContainer = "container:Runner.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "97C146ED1CF9000F007C117D"
            BuildableName = "Runner.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </MacroExpansion>
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      enableGPUValidationMode = "1"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "97C146ED1CF9000F007C117D"
            BuildableName = "Runner.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Profile"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "97C146ED1CF9000F007C117D"
            BuildableName = "Runner.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
EOL

# Step 7: Update Flutter.xcconfig files to ensure proper framework paths
echo "Updating Flutter.xcconfig files..."
mkdir -p ios/Flutter
cat > ios/Flutter/Debug.xcconfig << 'EOL'
#include "Generated.xcconfig"
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
FRAMEWORK_SEARCH_PATHS = $(inherited) "${PODS_ROOT}/../Flutter" "${PODS_CONFIGURATION_BUILD_DIR}"
HEADER_SEARCH_PATHS = $(inherited) "${PODS_ROOT}/Headers/Public" "${PODS_CONFIGURATION_BUILD_DIR}/**" "${PODS_ROOT}/../Flutter"
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) EXTENSION=0 COCOAPODS=1
EOL

cat > ios/Flutter/Release.xcconfig << 'EOL'
#include "Generated.xcconfig"
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
FRAMEWORK_SEARCH_PATHS = $(inherited) "${PODS_ROOT}/../Flutter" "${PODS_CONFIGURATION_BUILD_DIR}"
HEADER_SEARCH_PATHS = $(inherited) "${PODS_ROOT}/Headers/Public" "${PODS_CONFIGURATION_BUILD_DIR}/**" "${PODS_ROOT}/../Flutter"
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) EXTENSION=0 COCOAPODS=1
EOL

# Step 8: Try to build
echo "Building the app..."
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ios --debug --no-codesign

echo "Script completed!" 