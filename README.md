# QuickMute

**QuickMute** is a lightweight, high-performance macOS menu bar application that intercepts the **F5** key globally to mute and unmute your default microphone system-wide. 

Because it operates directly at the macOS CoreAudio level, muting is reflected globally across all communication platforms—guaranteeing compatibility with **WhatsApp, FaceTime, Zoom, Microsoft Teams, Slack, Webex, Discord, Chrome, Safari**, and any other audio-recording software.

---

## Key Features

*   **Universal Compatibility**: Silences the microphone at the hardware abstraction layer (CoreAudio). Apps receive absolute silence.
*   **Zero-Permission Hotkey**: Uses Carbon Event Manager to intercept global keystrokes. Unlike keyboard sniffers or standard event monitors, **QuickMute does not require intrusive Accessibility (Assistive Device) permissions**.
*   **Dynamic Device Synchronization**: Automatically detects changes to your system's default input source (e.g., unplugging a USB mic, wearing AirPods, or connecting a headset) and binds its listeners and mute states to the new device in real-time.
*   **Native Bezel HUD**: Displays a glassmorphic overlay panel centered on screen when the status changes. Built using `NSVisualEffectView` with `.hudWindow` material to match the macOS native volume HUD.
*   **Acoustic Indicators**: Plays a system `Pop` sound when muting and a high-pitched `Tink` sound when unmuting.
*   **Launch at Login**: Integrates with modern macOS `SMAppService` APIs to register as a boot agent.
*   **Customization Menu**: Left/Right-click the menu bar microphone icon to toggle the HUD, sound indicators, launch-at-login settings, or quit the application.

---

## Production-Level Versioning

QuickMute conforms to standard macOS production-level versioning guidelines, utilizing two keys within `Info.plist`:

1.  **Marketing Version (`CFBundleShortVersionString`)**:
    *   The user-visible version string (e.g., `1.0.0`, `2.1.3`).
    *   Follows [Semantic Versioning (SemVer)](https://semver.org/).
2.  **Build Version (`CFBundleVersion`)**:
    *   The internal revision/compilation number (e.g., `1`, `48`, `204`).
    *   An integer that monotonically increases with every compilation/release pipeline step.

### Automated Injection
To prevent version fragmentation, version variables are injected dynamically during the distribution build pipeline. The `release.sh` script leverages the native macOS `plutil` utility to inject custom marketing and build versions directly into the packaged app bundle:

```bash
# Example syntax
./release.sh <marketing_version> <build_number>
```

---

## Project Structure

```
QuickMute/
├── main.swift             # Application entry point, disables stdout buffering.
├── AppDelegate.swift      # Orchestrates settings, sound play, login service, and menus.
├── MicrophoneManager.swift# Interfaces with CoreAudio (HAL) to toggle and monitor mute state.
├── HotKeyManager.swift    # Registers the global F5 hotkey hook using Carbon APIs.
├── HUDWindow.swift        # Renders the native glassmorphic HUD status display panel.
├── Info.plist             # Background agent properties and microphone descriptions.
├── build.sh               # Compilation script assembling QuickMute.app.
├── release.sh             # Production packaging script producing .dmg and .zip bundles.
└── .gitignore             # Standard macOS/Swift Git rules.
```

---

## How to Build & Run

### 1. Compile locally
Run the compilation script to compile the Swift source files:
```bash
./build.sh
```
This compiles the executable and organizes it into a sandboxed app bundle: `QuickMute.app`.

### 2. Run the App
To start the app in the background:
```bash
open QuickMute.app
```
You will see the microphone icon in your status bar menu.

### 3. Generate Production Releases (with Versioning)
To package the app for distribution, run the release script, optionally passing a marketing version and build number:
```bash
# Packages default version 1.0.0 (Build 1)
./release.sh

# Packages custom version 1.1.2 (Build 45)
./release.sh 1.1.2 45
```
This script updates the `Info.plist` inside the bundle and outputs:
- **`QuickMute.dmg`**: A compressed Disk Image containing a shortcut link to `/Applications` for easy drag-and-drop user installation.
- **`QuickMute.zip`**: A standard compressed archive containing the app bundle.

---

## Interacting with the Application

*   **Triggering the Mute State**:
    *   By default on macOS, function keys behave as media keys (brightness, keyboard backlight, dictation).
    *   To trigger the mute toggle, press **`Fn + F5`** (or Globe + F5).
    *   Alternatively, go to **System Settings > Keyboard > Keyboard Shortcuts > Function Keys** and enable **"Use F1, F2, etc. keys as standard function keys"** to trigger the mute toggle by pressing **F5** directly.
*   **Status Indicators**:
    *   *Menu Bar Icon*: Displays an active mic glyph or a slashed mic glyph. The icon turns **red** when muted.
    *   *HUD overlay*: Renders a transient overlay stating "Microphone Muted" or "Microphone Active".
