import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var microphoneManager: MicrophoneManager!
    private var hotKeyManager: HotKeyManager!
    private var lastMuteState: Bool? = nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize default preferences
        UserDefaults.standard.register(defaults: [
            "hudEnabled": true,
            "soundEnabled": true
        ])

        // Configure Status Bar Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Initialize Microphone and HotKey Managers
        microphoneManager = MicrophoneManager()
        hotKeyManager = HotKeyManager()

        // Set up callback loops
        microphoneManager.onMuteStatusChanged = { [weak self] isMuted in
            self?.updateStatusItem(isMuted: isMuted)
            self?.showFeedback(isMuted: isMuted)
        }

        hotKeyManager.onKeyPressed = { [weak self] in
            self?.microphoneManager.toggleMute()
        }

        // Initialize UI State
        let currentMute = microphoneManager.isMuted()
        updateStatusItem(isMuted: currentMute)
        lastMuteState = currentMute

        setupMenu()
    }

    private func updateStatusItem(isMuted: Bool) {
        guard let button = statusItem.button else { return }
        
        let iconName = isMuted ? "mic.slash.fill" : "mic.fill"
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            image.isTemplate = true
            button.image = image
        }
        
        if isMuted {
            button.contentTintColor = .systemRed
        } else {
            button.contentTintColor = nil
        }
        
        button.toolTip = isMuted ? "Microphone Muted (F5 to Unmute)" : "Microphone Active (F5 to Mute)"
    }

    private func showFeedback(isMuted: Bool) {
        guard let previousState = lastMuteState else {
            lastMuteState = isMuted
            return
        }

        // Only flash HUD and play sound on state transition
        if previousState == isMuted { return }
        lastMuteState = isMuted

        if UserDefaults.standard.bool(forKey: "hudEnabled") {
            HUDWindow.shared.show(isMuted: isMuted)
        }

        if UserDefaults.standard.bool(forKey: "soundEnabled") {
            if isMuted {
                NSSound(named: "Pop")?.play()
            } else {
                NSSound(named: "Tink")?.play()
            }
        }
    }

    // MARK: - Menu Setup

    private func setupMenu() {
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "QuickMute v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: "Toggle Mute", action: #selector(toggleMuteClicked), keyEquivalent: "")
        // NSF5FunctionKey is 0xF708
        if let f5Scalar = UnicodeScalar(0xF708) {
            toggleItem.keyEquivalent = String(f5Scalar)
            toggleItem.keyEquivalentModifierMask = []
        }
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // HUD Toggle
        let hudItem = NSMenuItem(title: "Show HUD Notification", action: #selector(toggleHUDSetting), keyEquivalent: "")
        hudItem.target = self
        hudItem.state = UserDefaults.standard.bool(forKey: "hudEnabled") ? .on : .off
        menu.addItem(hudItem)
        
        // Sound Toggle
        let soundItem = NSMenuItem(title: "Play Sound Feedback", action: #selector(toggleSoundSetting), keyEquivalent: "")
        soundItem.target = self
        soundItem.state = UserDefaults.standard.bool(forKey: "soundEnabled") ? .on : .off
        menu.addItem(soundItem)
        
        // Launch at Login Toggle
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchSetting), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(launchItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit QuickMute", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }

    // MARK: - Selectors

    @objc private func toggleMuteClicked() {
        microphoneManager.toggleMute()
    }
    
    @objc private func toggleHUDSetting(_ sender: NSMenuItem) {
        let current = UserDefaults.standard.bool(forKey: "hudEnabled")
        UserDefaults.standard.set(!current, forKey: "hudEnabled")
        sender.state = !current ? .on : .off
    }
    
    @objc private func toggleSoundSetting(_ sender: NSMenuItem) {
        let current = UserDefaults.standard.bool(forKey: "soundEnabled")
        UserDefaults.standard.set(!current, forKey: "soundEnabled")
        sender.state = !current ? .on : .off
    }
    
    @objc private func toggleLaunchSetting(_ sender: NSMenuItem) {
        let current = isLaunchAtLoginEnabled
        updateLaunchAtLogin(enabled: !current)
        sender.state = !current ? .on : .off
    }
    
    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Launch at Login Helper

    private var isLaunchAtLoginEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("QuickMute: Successfully registered for Launch at Login")
            } else {
                try SMAppService.mainApp.unregister()
                print("QuickMute: Successfully unregistered for Launch at Login")
            }
        } catch {
            print("QuickMute: Error setting Launch at Login: \(error.localizedDescription)")
        }
    }
}
