#!/bin/bash

echo "Resetting Xcode build system..."

# Kill any running Xcode processes
echo "Closing any running Xcode instances..."
killall Xcode || true
sleep 2

# Clean Xcode's DerivedData
echo "Cleaning Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData
mkdir -p ~/Library/Developer/Xcode/DerivedData

# Clean Xcode's ModuleCache
echo "Cleaning Xcode ModuleCache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache
mkdir -p ~/Library/Developer/Xcode/DerivedData/ModuleCache

# Clean iOS project
echo "Cleaning iOS project..."
cd ios

# Remove pods and reinstall
echo "Removing Pods and reinstalling..."
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

# Reinstall pods
echo "Reinstalling pods..."
pod install --repo-update

echo "Xcode build system reset completed!"
echo "Now run 'open ios/Runner.xcworkspace' and build again" 