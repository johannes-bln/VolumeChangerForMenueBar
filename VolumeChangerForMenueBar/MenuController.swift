import Cocoa
import CoreAudio

final class MenuController: NSObject, NSMenuDelegate {
    private let audio: AudioManager
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var refreshTimer: Timer?
    private var outputLevel: Float = 0
    private var inputLevel: Float?
    private var inputMuted = false
    private var lastRenderedIconState: StatusIconState?

    private struct StatusIconState: Equatable {
        let outputPercent: Int
        let speakerSymbolName: String
        let inputMuted: Bool
    }

    init(audio: AudioManager) {
        self.audio = audio
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        super.init()

        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "VolumeChangerForMenueBar"

        updateIcon()
        rebuildMenu()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
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

        let devices = audio.devices()
        addDeviceSection(title: "Input", direction: .input, devices: devices)
        menu.addItem(.separator())
        addDeviceSection(title: "Output", direction: .output, devices: devices)
        menu.addItem(.separator())
        addSlider(title: "Input Volume", direction: .input)
        addSlider(title: "Output Volume", direction: .output)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About", action: #selector(openAboutWebpage), keyEquivalent: "i", target: self))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q", target: self))
    }

    private func addDeviceSection(title: String, direction: AudioDirection, devices allDevices: [AudioDevice]) {
        let titleItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let devices = allDevices.filter { device in
            switch direction {
            case .input:
                return device.hasInput
            case .output:
                return device.hasOutput
            }
        }
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
            guard let self else {
                return
            }

            guard self.audio.setVolume(level, for: direction) else {
                return
            }

            if direction == .output {
                self.outputLevel = level
            } else {
                self.inputLevel = level
                self.inputMuted = level <= 0.01
            }
            self.renderIcon()
        }

        menu.addItem(item)
    }

    private func updateIcon() {
        let outputLevel = audio.volume(for: .output) ?? 0
        let inputLevel = audio.volume(for: .input)
        let inputMuted = audio.isMuted(for: .input) ?? (inputLevel.map { $0 <= 0.01 } ?? false)

        guard self.outputLevel != outputLevel || self.inputLevel != inputLevel ||
                self.inputMuted != inputMuted || lastRenderedIconState == nil else {
            return
        }

        self.outputLevel = outputLevel
        self.inputLevel = inputLevel
        self.inputMuted = inputMuted
        renderIcon()
    }

    private func renderIcon() {
        let level = outputLevel
        let percent = Int(round(Double(level * 100)))

        let symbolName: String

        if level <= 0.01 {
            symbolName = "speaker.slash.fill"
        } else if level < 0.34 {
            symbolName = "speaker.wave.1.fill"
        } else if level < 0.67 {
            symbolName = "speaker.wave.2.fill"
        } else {
            symbolName = "speaker.wave.3.fill"
        }

        let isInputMuted = inputMuted
        let state = StatusIconState(
            outputPercent: percent,
            speakerSymbolName: symbolName,
            inputMuted: isInputMuted
        )
        guard lastRenderedIconState != state else {
            return
        }
        lastRenderedIconState = state

        let image = statusBarImage(
            speakerSymbolName: symbolName,
            showsMutedInput: isInputMuted
        )

        statusItem.length = isInputMuted ? 64 : NSStatusItem.squareLength
        image?.isTemplate = !isInputMuted
        statusItem.button?.image = image
        statusItem.button?.toolTip = isInputMuted
            ? "Input Muted · Output Volume: \(percent) %"
            : "Output Volume: \(percent) %"
    }

    private func statusBarImage(speakerSymbolName: String, showsMutedInput: Bool) -> NSImage? {
        guard showsMutedInput else {
            return NSImage(systemSymbolName: speakerSymbolName, accessibilityDescription: "Output Volume")
        }

        let imageSize = NSSize(width: 54, height: 18)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        drawSymbol("microphone.slash.fill", color: .labelColor, in: NSRect(x: 0, y: 0, width: 17, height: 18))
        drawSymbol(speakerSymbolName, color: .labelColor, in: NSRect(x: 29, y: 0, width: 25, height: 18))

        image.unlockFocus()
        return image
    }

    private func drawSymbol(_ symbolName: String, color: NSColor, in rect: NSRect) {
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            return
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let configuredSymbol = symbol.withSymbolConfiguration(configuration) ?? symbol
        configuredSymbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        color.setFill()
        rect.fill(using: .sourceAtop)
    }

    private func selectDevice(_ deviceID: AudioDeviceID, direction: AudioDirection) {
        audio.setDefaultDevice(deviceID, for: direction)
        updateIcon()

        menu.cancelTracking()
        rebuildMenu()
    }

    @objc private func openAboutWebpage() {
        guard let url = URL(string: "https://github.com/johannes-bln/VolumeChangerForMenueBar") else {
            return
        }

        NSWorkspace.shared.open(url)
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
