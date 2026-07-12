import Cocoa

class HUDWindow: NSPanel {
    private let imageView = NSImageView()
    private let label = NSTextField()
    private var fadeOutTimer: Timer?

    static let shared = HUDWindow()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .statusBar
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        
        setupViews()
    }
    
    private func setupViews() {
        let visualEffect = NSVisualEffectView()
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 24
        visualEffect.layer?.masksToBounds = true
        
        contentView?.addSubview(visualEffect)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 15, weight: .bold)
        label.alignment = .center
        
        visualEffect.addSubview(imageView)
        visualEffect.addSubview(label)
        
        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: contentView!.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),
            
            imageView.centerXAnchor.constraint(equalTo: visualEffect.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 32),
            imageView.widthAnchor.constraint(equalToConstant: 76),
            imageView.heightAnchor.constraint(equalToConstant: 76),
            
            label.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -28)
        ])
    }
    
    func show(isMuted: Bool) {
        // Cancel existing timer
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        
        // Update content
        if isMuted {
            if let img = NSImage(systemSymbolName: "mic.slash.fill", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 76, weight: .medium)
                imageView.image = img.withSymbolConfiguration(config)
                imageView.contentTintColor = .systemRed
            }
            label.stringValue = "Microphone Muted"
        } else {
            if let img = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 76, weight: .medium)
                imageView.image = img.withSymbolConfiguration(config)
                imageView.contentTintColor = .white
            }
            label.stringValue = "Microphone Active"
        }
        
        // Position window in the center of the main screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.size.width - 180) / 2
            let y = screenRect.origin.y + (screenRect.size.height - 180) / 2
            self.setFrame(NSRect(x: x, y: y, width: 180, height: 180), display: true)
        }
        
        // Reset transparency and bring to front
        self.alphaValue = 1.0
        self.orderFrontRegardless()
        
        // Fade out after a delay
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.animator().alphaValue = 0.0
            }, completionHandler: {
                if self.alphaValue == 0.0 {
                    self.orderOut(nil)
                }
            })
        }
    }
}
