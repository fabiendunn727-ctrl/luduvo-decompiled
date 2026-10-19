# Luduvo iOS client

Native iOS client for the Luduvo engine: UIKit shell, Metal renderer, MoltenVK
for the Vulkan backend and a virtual touch HUD.

```
Luduvo/Source      Swift app code (AppDelegate, GameViewController, touch HUD)
Luduvo/Engine      Objective-C/C++ engine bridge, Metal renderer, MoltenVK wrapper
Luduvo/Resources   Info.plist, entitlements, asset catalog, launch screen
Vendor/MoltenVK    vendored MoltenVK static library (iOS arm64 slice)
scripts            project generator
```

## Building the IPA

The unsigned IPA is produced by GitHub Actions
(`.github/workflows/mobile-ios.yml`) on a macOS runner:

```sh
xcodebuild -project mobile/ios/Luduvo.xcodeproj -scheme Luduvo \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_ENTITLEMENTS="" PROVISIONING_PROFILE_SPECIFIER="" \
  ENABLE_BITCODE=NO ONLY_ACTIVE_ARCH=NO ARCHS=arm64 build
```

Then package it:

```sh
cd build/Build/Products/Release-iphoneos
mkdir -p Payload && cp -R Luduvo.app Payload/ && zip -qry Luduvo-unsigned.ipa Payload
```

The result is unsigned - sideload it with Sideloadly, AltStore or TrollStore.

The `LuduvoEditor` scheme builds the studio variant (`com.luduvo.studio`); the
client scheme builds the game (`com.luduvo.client`).

## Regenerating the Xcode project

The project file is generated, not hand-edited. After adding or removing a
source file:

```sh
cd mobile/ios && ruby scripts/generate_project.rb
```

The script needs the `xcodeproj` gem (`gem install xcodeproj`).

## Engine library

`libluduvo.dylib` is not part of this repository. The app resolves it at
runtime from the app bundle (`@rpath/libluduvo.dylib`); when it is missing the
client runs in shell mode with the built-in Metal renderer and the touch HUD
still working.
