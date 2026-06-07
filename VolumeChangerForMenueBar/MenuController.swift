import Cocoa
import CoreAudio

final class MenuController: NSObject, NSMenuDelegate {
    private let audio: AudioManager
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var refreshTimer: Timer?

    init(audio: AudioManager) {
        self.audio = audio
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        super.init()

        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "VolumeHelper"

        updateIcon()
        rebuildMenu()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateIcon()
        }
    }

    deinit {
        refreshTimer?.invalidate()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addDeviceSection(title: "Input", direction: .input)
        menu.addItem(.separator())
        addDeviceSection(title: "Output", direction: .output)
        menu.addItem(.separator())
        addSlider(title: "Input Volume", direction: .input)
        addSlider(title: "Output Volume", direction: .output)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q", target: self))
    }

    private func addDeviceSection(title: String, direction: AudioDirection) {
        let titleItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let devices = audio.devices(for: direction)
        let selectedDeviceID = audio.defaultDevice(for: direction)

        titleItem.isEnabled = false
        menu.addItem(titleItem)

        if devices.isEmpty {
            let emptyItem = NSMenuItem(title: "No devices", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            emptyItem.indentationLevel = 1
            menu.addItem(emptyItem)
        }

        for device in devices {
            let item = DeviceMenuItem(
                title: device.name,
                isSelected: device.id == selectedDeviceID
            ) { [weak self] in
                self?.selectDevice(device.id, direction: direction)
            }

            menu.addItem(item)
        }
    }

    private func addSlider(title: String, direction: AudioDirection) {
        let value = audio.volume(for: direction)
        let item = SliderMenuItem(title: title, value: value ?? 0, isEnabled: value != nil) { [weak self] level in
            self?.audio.setVolume(level, for: direction)
            self?.updateIcon()
        }

        menu.addItem(item)
    }

    private func updateIcon() {
        let level = audio.volume(for: .output) ?? 0
        let percent = Int(round(Double(level * 100)))
        let symbolName: String

        if level <= 0.01 {
            symbolName = "speaker.slash"
        } else if level < 0.34 {
            symbolName = "speaker.wave.1"
        } else if level < 0.67 {
            symbolName = "speaker.wave.2"
        } else {
            symbolName = "speaker.wave.3"
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VolumeHelper")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Output Volume: \(percent) %"
    }

    private func selectDevice(_ deviceID: AudioDeviceID, direction: AudioDirection) {
        audio.setDefaultDevice(deviceID, for: direction)

        if direction == .output {
            updateIcon()
        }

        menu.cancelTracking()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private extension NSMenuItem {
    convenience init(title: String, action: Selector?, keyEquivalent: String, target: AnyObject?) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.target = target
    }
}
