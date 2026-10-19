#!/usr/bin/env ruby
# Regenerates mobile/ios/Luduvo.xcodeproj from scratch.
#
# The checked-in project file was hand-written and had dangling object
# references (frameworks without file references, targets without build
# settings, sources pointing at files that did not exist). Building it is
# impossible, so the project is generated instead. Run:
#
#   ruby mobile/ios/scripts/generate_project.rb
#
require 'xcodeproj'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)            # mobile/ios
PROJECT_PATH = File.join(ROOT, 'Luduvo.xcodeproj')
DEPLOYMENT_TARGET = '15.0'
BUNDLE_ID = 'com.luduvo.client'
EDITOR_BUNDLE_ID = 'com.luduvo.studio'

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)

project.build_configurations.each do |config|
  config.build_settings.merge!(
    'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
    'SDKROOT' => 'iphoneos',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'SWIFT_VERSION' => '5.0',
    'CLANG_ENABLE_MODULES' => 'YES',
    'CLANG_ENABLE_OBJC_ARC' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_C_LANGUAGE_STANDARD' => 'gnu17',
    'ENABLE_STRICT_OBJC_MSGSEND' => 'YES',
    'GCC_WARN_ABOUT_RETURN_TYPE' => 'YES_ERROR',
    'GCC_WARN_UNDECLARED_SELECTOR' => 'YES',
    'GCC_WARN_UNINITIALIZED_AUTOS' => 'YES_AGGRESSIVE',
    'GCC_WARN_UNUSED_FUNCTION' => 'YES',
    'GCC_WARN_UNUSED_VARIABLE' => 'YES',
    'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING' => 'YES',
    'CLANG_WARN_BOOL_CONVERSION' => 'YES',
    'CLANG_WARN_COMMA' => 'YES',
    'CLANG_WARN_CONSTANT_CONVERSION' => 'YES',
    'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS' => 'YES',
    'CLANG_WARN_DIRECT_OBJC_ISA_USAGE' => 'YES_ERROR',
    'CLANG_WARN_DOCUMENTATION_COMMENTS' => 'YES',
    'CLANG_WARN_EMPTY_BODY' => 'YES',
    'CLANG_WARN_ENUM_CONVERSION' => 'YES',
    'CLANG_WARN_INFINITE_RECURSION' => 'YES',
    'CLANG_WARN_OBJC_IMPLICIT_ATOMIC_PROPERTIES' => 'YES',
    'CLANG_WARN_OBJC_LITERAL_CONVERSION' => 'YES',
    'CLANG_WARN_OBJC_ROOT_CLASS' => 'YES_ERROR',
    'CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER' => 'YES',
    'CLANG_WARN_SUSPICIOUS_MOVE' => 'YES',
    'CLANG_WARN_UNREACHABLE_CODE' => 'YES',
    'CLANG_WARN__DUPLICATE_METHOD_MATCH' => 'YES',
    'ALWAYS_SEARCH_USER_PATHS' => 'NO',
    'COPY_PHASE_STRIP' => 'NO',
    'DEBUG_INFORMATION_FORMAT' => 'dwarf-with-dsym',
    'ENABLE_TESTABILITY' => 'YES',
    'GCC_OPTIMIZATION_LEVEL' => 's',
    'MTL_ENABLE_DEBUG_INFO' => 'INCLUDE_SOURCE',
    'MTL_FAST_MATH' => 'YES',
    'ONLY_ACTIVE_ARCH' => 'NO',
    'SWIFT_OPTIMIZATION_LEVEL' => '-O',
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
    'VALIDATE_PRODUCT' => 'YES',
    'CODE_SIGN_STYLE' => 'Automatic',
    'DEVELOPMENT_TEAM' => '',
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/Frameworks'
    ]
  )
end

# ---------------------------------------------------------------- groups
main_group = project.main_group

luduvo_group = main_group.find_subpath('Luduvo', true)
luduvo_group.set_source_tree('SOURCE_ROOT')

source_group = luduvo_group.find_subpath('Source', true)
source_group.set_source_tree('SOURCE_ROOT')
engine_group = luduvo_group.find_subpath('Engine', true)
engine_group.set_source_tree('SOURCE_ROOT')
resources_group = luduvo_group.find_subpath('Resources', true)
resources_group.set_source_tree('SOURCE_ROOT')
vendor_group = main_group.find_subpath('Vendor', true)
vendor_group.set_source_tree('SOURCE_ROOT')
moltenvk_group = vendor_group.find_subpath('MoltenVK', true)
moltenvk_group.set_source_tree('SOURCE_ROOT')

# ---------------------------------------------------------------- sources
source_refs = [
  source_group.new_file('Luduvo/Source/AppDelegate.swift'),
  source_group.new_file('Luduvo/Source/GameViewController.swift'),
  source_group.new_file('Luduvo/Source/EditorViewController.swift'),
  source_group.new_file('Luduvo/Source/TouchControlOverlay.swift'),
  source_group.new_file('Luduvo/Source/Luduvo-Bridging-Header.h')
]

engine_refs = [
  engine_group.new_file('Luduvo/Engine/LuduvoEngine.h'),
  engine_group.new_file('Luduvo/Engine/LuduvoEngine.mm'),
  engine_group.new_file('Luduvo/Engine/LuduvoEngineShim.m'),
  engine_group.new_file('Luduvo/Engine/luduvo_engine_api.h'),
  engine_group.new_file('Luduvo/Engine/MetalRenderer.h'),
  engine_group.new_file('Luduvo/Engine/MetalRenderer.m'),
  engine_group.new_file('Luduvo/Engine/MoltenVKWrapper.hpp'),
  engine_group.new_file('Luduvo/Engine/MoltenVKWrapper.cpp'),
  engine_group.new_file('Luduvo/Engine/EngineBridge.cpp'),
  engine_group.new_file('Luduvo/Engine/LuduvoShellShaders.metal')
]

resource_refs = [
  resources_group.new_file('Luduvo/Resources/Assets.xcassets'),
  resources_group.new_file('Luduvo/Resources/LaunchScreen.storyboard')
]

info_plist_ref = resources_group.new_file('Luduvo/Resources/Info.plist')
entitlements_ref = resources_group.new_file('Luduvo/Resources/luduvo.entitlements')

# MoltenVK static library (vendored).
moltenvk_group.new_file('Vendor/MoltenVK/lib/libMoltenVK.a')

# ---------------------------------------------------------------- frameworks
frameworks = %w[
  UIKit
  Foundation
  Metal
  MetalKit
  QuartzCore
  CoreGraphics
  GameController
]

frameworks_group = main_group.find_subpath('Frameworks', true)
frameworks_group.set_source_tree('SOURCE_ROOT')

framework_refs = frameworks.map do |name|
  ref = frameworks_group.new_reference("System/Library/Frameworks/#{name}.framework")
  # Resolve the framework from the active SDK, not from the source directory.
  ref.source_tree = 'SDKROOT'
  ref
end

# MoltenVK static library (vendored).
moltenvk_lib_ref = moltenvk_group.new_file('Vendor/MoltenVK/lib/libMoltenVK.a')

# ---------------------------------------------------------------- targets
client = project.new_target(:application, 'Luduvo', :ios, DEPLOYMENT_TARGET)
editor = project.new_target(:application, 'LuduvoEditor', :ios, DEPLOYMENT_TARGET)

# new_target pre-seeds a Foundation.framework reference with an absolute SDK
# path. Drop it; the explicit System/Library references below are used instead.
[client, editor].each do |target|
  target.frameworks_build_phase.files.dup.each do |build_file|
    ref = build_file.file_ref
    next unless ref && ref.path.to_s.end_with?('Foundation.framework')
    target.frameworks_build_phase.remove_build_file(build_file)
    ref.remove_from_project
  end
end

def configure(app_target, sources, engine_files, resources, framework_refs,
              info_plist_ref, entitlements_ref, bundle_id, display_name,
              swift_sources, metal_sources, moltenvk_lib_ref)
  app_target.build_configurations.each do |config|
    config.build_settings.merge!(
      'PRODUCT_NAME' => '$(TARGET_NAME)',
      'PRODUCT_BUNDLE_IDENTIFIER' => bundle_id,
      'INFOPLIST_FILE' => 'Luduvo/Resources/Info.plist',
      'INFOPLIST_KEY_CFBundleDisplayName' => display_name,
      'GENERATE_INFOPLIST_FILE' => 'NO',
      'CODE_SIGN_ENTITLEMENTS' => 'Luduvo/Resources/luduvo.entitlements',
      'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
      'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
      'SWIFT_OBJC_BRIDGING_HEADER' => 'Luduvo/Source/Luduvo-Bridging-Header.h',
      'SWIFT_OBJC_INTERFACE_HEADER_NAME' => "#{app_target.name}-Swift.h",
      'LD_RUNPATH_SEARCH_PATHS' => [
        '$(inherited)',
        '@executable_path/Frameworks'
      ],
      'HEADER_SEARCH_PATHS' => [
        '$(inherited)',
        '$(SRCROOT)/Vendor/MoltenVK/include',
        '$(SRCROOT)/Luduvo/Engine'
      ],
      'LIBRARY_SEARCH_PATHS' => [
        '$(inherited)',
        '$(SRCROOT)/Vendor/MoltenVK/lib'
      ],
      'OTHER_LDFLAGS' => [
        '$(inherited)',
        '-ObjC'
      ],
      'LDV_PLATFORM_IOS' => '1',
      'LDV_ENABLE_MOLTENVK' => '1',
      'MTL_ENABLE_DEBUG_INFO' => 'INCLUDE_SOURCE',
      'DEAD_CODE_STRIPPING' => 'YES'
    )
    config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
    config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] += [
      'LDV_PLATFORM_IOS=1',
      'LDV_ENABLE_MOLTENVK=1'
    ]
  end

  # Compile sources.
  (sources + engine_files + metal_sources).each do |ref|
    app_target.source_build_phase.add_file_reference(ref)
  end

  # Resources.
  resources.each do |ref|
    app_target.resources_build_phase.add_file_reference(ref)
  end

  # Frameworks.
  framework_refs.each do |ref|
    app_target.frameworks_build_phase.add_file_reference(ref)
  end

  # Vendored MoltenVK static library.
  app_target.frameworks_build_phase.add_file_reference(moltenvk_lib_ref)
end

# The Metal shader file needs to be in the sources phase.
metal_source_refs = engine_refs.select { |r| r.path.end_with?('.metal') }
cpp_source_refs = engine_refs.reject { |r| r.path.end_with?('.metal') }
swift_source_refs = source_refs.select { |r| r.path.end_with?('.swift') }
objc_source_refs = source_refs.reject { |r| r.path.end_with?('.swift') }

configure(client, swift_source_refs, objc_source_refs + cpp_source_refs, resource_refs,
          framework_refs, info_plist_ref, entitlements_ref, BUNDLE_ID, 'Luduvo',
          swift_source_refs, metal_source_refs, moltenvk_lib_ref)

configure(editor, swift_source_refs, objc_source_refs + cpp_source_refs, resource_refs,
          framework_refs, info_plist_ref, entitlements_ref, EDITOR_BUNDLE_ID, 'Luduvo Studio',
          swift_source_refs, metal_source_refs, moltenvk_lib_ref)

# The editor also needs the EditorViewController as its root; it is already
# compiled into both targets above.

# ---------------------------------------------------------------- schemes
project.save

[client, editor].each do |target|
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  scheme.save_as(PROJECT_PATH, target.name, true)
end

puts "Generated #{PROJECT_PATH}"
puts "  targets: #{client.name}, #{editor.name}"
