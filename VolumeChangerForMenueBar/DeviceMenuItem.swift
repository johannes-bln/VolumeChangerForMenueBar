import Cocoa

final class DeviceMenuItem: NSMenuItem {
    init(title: String, isSelected: Bool, onSelect: @escaping () -> Void) {
        super.init(title: "", action: nil, keyEquivalent: "")
        view = DeviceMenuItemView(title: title, isSelected: isSelected, onSelect: onSelect)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class DeviceMenuItemView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let onSelect: () -> Void
    private let isSelected: Bool
    private var isHovered = false

    override var isFlipped: Bool {
        true
    }

    init(title: String, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.isSelected = isSelected
        self.onSelect = onSelect

        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 26))

        wantsLayer = true
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textColor = isSelected ? .selectedMenuItemTextColor : .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for area in trackingAreas {
            removeTrackingArea(area)
        }

        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        onSelect()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let backgroundRect = bounds.insetBy(dx: 8, dy: 2)
        let path = NSBezierPath(roundedRect: backgroundRect, xRadius: 5, yRadius: 5)

        if isSelected {
            NSColor.controlAccentColor.setFill()
            path.fill()
        } else if isHovered {
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18).setFill()
            path.fill()
        }
    }
}
