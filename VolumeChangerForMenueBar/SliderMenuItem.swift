import Cocoa

final class SliderMenuItem: NSMenuItem {
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let valueLabel = NSTextField(labelWithString: "")
    private let onChange: (Float) -> Void

    init(title: String, value: Float, isEnabled: Bool, onChange: @escaping (Float) -> Void) {
        self.onChange = onChange

        super.init(title: title, action: nil, keyEquivalent: "")

        slider.target = self
        slider.action = #selector(valueChanged)
        slider.isContinuous = true
        slider.isEnabled = isEnabled

        let row = SliderRowView(title: title, slider: slider, valueLabel: valueLabel)
        view = row

        setValue(value)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setValue(_ value: Float) {
        let percent = Int(round(Double(value * 100)))
        slider.doubleValue = Double(percent)
        valueLabel.stringValue = "\(percent) %"
    }

    @objc private func valueChanged() {
        let percent = Int(round(slider.doubleValue))
        valueLabel.stringValue = "\(percent) %"
        onChange(Float(slider.doubleValue / 100))
    }
}

final class SliderRowView: NSView {
    init(title: String, slider: NSSlider, valueLabel: NSTextField) {
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 54))

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.alignment = .right

        let header = NSStackView(views: [titleLabel, valueLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        header.spacing = 8

        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [header, slider])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            slider.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}
