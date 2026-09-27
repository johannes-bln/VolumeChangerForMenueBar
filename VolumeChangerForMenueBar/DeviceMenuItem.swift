import Cocoa

final class DeviceMenuItem: NSMenuItem {
    private let onSelect: () -> Void

    init(title: String, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.onSelect = onSelect

        super.init(title: title, action: #selector(selectDevice), keyEquivalent: "")

        state = isSelected ? .on : .off
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func selectDevice() {
        onSelect()
    }
}
