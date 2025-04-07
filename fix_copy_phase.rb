#!/usr/bin/env ruby

require 'xcodeproj'

# Path to the Xcode project file
project_path = 'ios/Runner.xcodeproj'

# Open the project
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'Runner' }

# Find the build phases that copy app directories recursively
copy_phases = target.build_phases.select { |phase| 
  phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
  phase.dst_path.include?("Products")
}

# Remove these problematic copy phases
copy_phases.each do |phase|
  puts "Removing build phase: #{phase.display_name}"
  target.build_phases.delete(phase)
end

# Save the project
project.save

puts "Successfully fixed Xcode project to prevent recursive app nesting"
