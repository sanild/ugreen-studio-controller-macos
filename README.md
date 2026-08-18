# Studio Controller for macOS

An independent menu-bar controller for **UGREEN Studio Pro (HP206)**
headphones. It talks directly to the headphones over Bluetooth and does not
require a phone, account, or internet connection.

## Download

Download the latest `Studio-Controller-macOS.zip` from
[GitHub Releases](https://github.com/sanild/ugreen-studio-controller-macos/releases/latest).

The app requires macOS 13 Ventura or newer.

## Install

1. Download and unzip `Studio-Controller-macOS.zip`.
2. Move **Studio Controller.app** into your Applications folder.
3. Pair and connect **UGREEN Studio Pro** in System Settings → Bluetooth.
4. Control-click the app and choose **Open**. Because this independent build is
   not notarized by Apple, macOS may ask you to confirm the first launch.
5. Allow Bluetooth access when prompted.

Studio Controller appears as a headphones icon in the menu bar.

## Features

- ANC, off, and ambient listening modes
- Ultra, general, gentle, and adaptive ANC strength
- Eight UGREEN EQ presets
- English voice announcements or beep-only headphone prompts
- Spatial audio, game mode, wind-noise reduction, and dual-device mode
- ANC-button single, double, and long-press assignments
- Volume +/− hold assignments
- Battery and firmware display

The power button's actions are fixed by the headphone firmware and cannot be
remapped. Firmware updating and factory reset are deliberately not implemented.

## Privacy

Studio Controller communicates locally with the paired headphones. It has no
analytics, accounts, update service, or network features.

## Build from source

Install the current Xcode Command Line Tools, then run:

```sh
./scripts/test.sh
./scripts/build-app.sh
```

The packaged app is written to `build/Studio Controller.app`. The protocol test
runner is standalone because some Command Line Tools distributions do not ship
XCTest or Swift Testing with the SDK.

The original app icon artwork is stored in `Assets/AppIcon-master.png`.
`scripts/build-icon.sh` creates the complete macOS `.icns` resource.

## Compatibility

The protocol implementation is model-specific and currently supports UGREEN
Studio Pro (HP206). It was derived from UGREEN's published Android client for
interoperability with personally owned hardware.

This project is not affiliated with, authorized by, or endorsed by UGREEN.
UGREEN and Studio Pro are trademarks of their respective owner.

## License

[MIT](LICENSE)
