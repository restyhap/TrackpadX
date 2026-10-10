import Cocoa
import PreferencePanes

// P 路线实验: legacy NSPreferencePane, 目标出现在 macOS 27 系统设置侧栏
// 失败场景预期: 侧栏不显示 / 加载报错 → 回退 A 路线(应用内设置窗)
// 纯代码构建 view, 不依赖 XIB; 存储NSUserDefaults suite 与应用内一致
@objc(TrackpadXPane)
final class TrackpadXPane: NSPreferencePane {

    // tag 约定: 0=三指下滑 1=输入时屏蔽触摸板
    private var threeFingerSwitch: NSSwitch!
    private var blockerSwitch: NSSwitch!

    // 代码路径: 覆写 loadMainView, 不走 NSMainNibFile
    override func loadMainView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 240))
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32),
        ])

        let title = NSTextField(labelWithString: "触摸板扩展")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        stack.addArrangedSubview(title)

        threeFingerSwitch = makeSwitch(tag: 0, state: Store.threeFingerEnabled)
        blockerSwitch = makeSwitch(tag: 1, state: Store.blockerEnabled)
        stack.addArrangedSubview(makeRow("三指下滑", threeFingerSwitch))
        stack.addArrangedSubview(makeCaption("三指下滑最小化当前前台应用的聚焦窗口。需辅助功能与输入监控权限。"))
        stack.addArrangedSubview(makeRow("输入时屏蔽触摸板", blockerSwitch))
        stack.addArrangedSubview(makeCaption("打字后短暂屏蔽鼠标移动与点击，防止手掌误触。"))
        return container
    }

    override func willSelect() {
        super.willSelect()
        threeFingerSwitch?.state = Store.threeFingerEnabled ? .on : .off
        blockerSwitch?.state = Store.blockerEnabled ? .on : .off
    }

    // MARK: - 构建
    private func makeRow(_ text: String, _ control: NSSwitch) -> NSView {
        let pair = NSStackView()
        pair.orientation = .horizontal
        pair.spacing = 8
        pair.addArrangedSubview(NSTextField(labelWithString: text))
        pair.addArrangedSubview(control)
        return pair
    }

    private func makeCaption(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeSwitch(tag: Int, state: Bool) -> NSSwitch {
        let sw = NSSwitch()
        sw.tag = tag
        sw.state = state ? .on : .off
        sw.target = self
        sw.action = #selector(switchChanged(_:))
        return sw
    }

    @objc private func switchChanged(_ sender: NSSwitch) {
        let on = sender.state == .on
        switch sender.tag {
        case 0: Store.threeFingerEnabled = on
        case 1: Store.blockerEnabled = on
        default: break
        }
    }
}
