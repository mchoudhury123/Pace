# Specify the platform and version
platform :ios, '14.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

# Specify your project - this is what's missing
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
    
    target.build_configurations.each do |config|
      # Add preprocessor definitions
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'COCOAPODS=1'
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'EXTENSION=0'
      
      # Fix BoringSSL-GRPC issues
      if target.name == 'BoringSSL-GRPC'
        # Remove the problematic flags from compiler settings
        config.build_settings['OTHER_CFLAGS'] = ['$(inherited)'] if config.build_settings['OTHER_CFLAGS'].nil?
        
        # Remove the -G flag which causes issues
        config.build_settings['OTHER_CFLAGS'] = config.build_settings['OTHER_CFLAGS'].select do |flag|
          flag != '-G' && !flag.to_s.include?('GCC_WARN_INHIBIT_ALL_WARNINGS')
        end
      end
      
      # Make all iOS deployment targets consistent
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end 