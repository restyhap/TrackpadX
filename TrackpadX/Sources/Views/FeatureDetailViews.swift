import AppKit
import ServiceManagement

/// 详情页通用骨架：标题区 + 内容栈
class DetailViewController: NSViewController {
    let detailTitle: String

    init(title: String) {
        detailTitle = title
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("不支持 coder 初始化") }

    let stack = NSStackView()
    private var stackBottom: NSLayoutConstraint!

    // TCC 授权不产生 Cocoa 通知可稳定依赖，用轻量轮询在授权返回后自动刷新 UI 与服务
    private var permissionTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.permissionPollTick()
        }
    }

    deinit {
        permissionTimer?.invalidate()
    }

    /// 子类覆写：检测权限状态变化（授权后即使不切页也能即时更新 UI/服务）
    func permissionPollTick() {}

    override func loadView() {
        let container = NSView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
        ])
        let trailing = stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -28)
        trailing.isActive = true
        stackBottom = stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24)
        stackBottom.isActive = true

        let titleLabel = NSTextField(labelWithString: detailTitle)
        titleLabel.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        stack.addArrangedSubview(titleLabel)

        view = container
    }

    /// 追加一行：标签 + 控件
    func row(_ label: String, _ control: NSView) -> NSView {
        let group = NSStackView()
        group.orientation = .horizontal
        group.alignment = .centerY
        group.spacing = 10
        let textLabel = NSTextField(labelWithString: label)
        textLabel.font = NSFont.systemFont(ofSize: 13)
        group.addArrangedSubview(textLabel)
        group.addArrangedSubview(control)
        group.translatesAutoresizingMaskIntoConstraints = false
        return group
    }

    /// 分区小标题（首页各区块共用）
    func sectionLabel(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    /// 说明文本（自动换行）
    func caption(_ text: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
        ])
        return label
    }
}

/// 通用页（设置首页）：权限状态 + 启动与关闭 + 关于
final class GeneralViewController: DetailViewController {
    private let registry = FeatureRegistry.shared

    private let threePermRow = NSStackView()
    private let blockerPermRow = NSStackView()
    private var lastPermThree: Bool?
    private var lastPermBlocker: Bool?

    init() {
        super.init(title: "通用")
    }

    required init?(coder: NSCoder) { fatalError("不支持 coder 初始化") }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 启动与关闭（可操作项置顶）
        stack.addArrangedSubview(sectionLabel("启动与关闭"))

        let autoStartSwitch = NSSwitch()
        autoStartSwitch.state = Store.autoStart ? .on : .off
        autoStartSwitch.target = self
        autoStartSwitch.action = #selector(autoStartToggled(_:))
        stack.addArrangedSubview(row("登录时启用", autoStartSwitch))
        stack.addArrangedSubview(caption("开机后自动在后台启动 TrackpadX，手势与防误触立即生效（无需打开设置窗口）。"))

        // 点击关闭按钮时的行为
        let closePopup = NSPopUpButton()
        closePopup.addItem(withTitle: "直接退出")
        closePopup.lastItem?.representedObject = 0
        closePopup.addItem(withTitle: "退出到后台运行")
        closePopup.lastItem?.representedObject = 1
        closePopup.selectItem(at: Store.closeAction == 1 ? 1 : 0)
        closePopup.target = self
        closePopup.action = #selector(closeActionChanged(_:))
        stack.addArrangedSubview(row("点击关闭按钮时", closePopup))
        stack.addArrangedSubview(caption("「直接退出」关闭窗口即退出应用；「退出到后台运行」仅收起窗口，功能继续生效，点击 Dock 图标可重新打开设置。"))

        // Dock 栏图标显示/隐藏（运行时切换激活策略，即时生效）
        let dockSwitch = NSSwitch()
        dockSwitch.state = Store.dockVisible ? .on : .off
        dockSwitch.target = self
        dockSwitch.action = #selector(dockVisibilityToggled(_:))
        stack.addArrangedSubview(row("在 Dock 栏显示图标", dockSwitch))
        stack.addArrangedSubview(caption("隐藏后即时生效且功能继续。设置窗口已关闭时，可从启动台 / Spotlight 重新打开应用唤回设置窗。"))

        // 权限状态（提示类内容置底）
        stack.addArrangedSubview(sectionLabel("权限状态"))
        threePermRow.orientation = .horizontal
        threePermRow.alignment = .centerY
        threePermRow.spacing = 10
        rebuildPermRow(threePermRow, ready: registry.threeFinger.permissionReady, hint: registry.threeFinger.permissionHint)
        stack.addArrangedSubview(row("三指下滑", threePermRow))
        blockerPermRow.orientation = .horizontal
        blockerPermRow.alignment = .centerY
        blockerPermRow.spacing = 10
        rebuildPermRow(blockerPermRow, ready: registry.blocker.permissionReady, hint: registry.blocker.permissionHint)
        stack.addArrangedSubview(row("输入时屏蔽触摸板", blockerPermRow))
        stack.addArrangedSubview(caption("授权后无需重启应用，权限自动生效。各功能的详细说明见对应设置页。"))
        lastPermThree = registry.threeFinger.permissionReady
        lastPermBlocker = registry.blocker.permissionReady

        // 关于
        stack.addArrangedSubview(sectionLabel("关于"))
        let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let appName = NSTextField(labelWithString: "TrackpadX  v\(ver)")
        appName.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(appName)
        stack.addArrangedSubview(caption("触摸板功能扩展：三指下滑最小化前台应用的聚焦窗口、输入时屏蔽触摸板防误触。\n标识符 com.resty.trackpadx · 兼容 macOS 13.0 及以上。"))
    }

    /// 授权状态变化即重建权限行；授权到位时让 registry 同步启停服务
    override func permissionPollTick() {
        let nowThree = registry.threeFinger.permissionReady
        let nowBlocker = registry.blocker.permissionReady
        let threeChanged = nowThree != lastPermThree
        let blockerChanged = nowBlocker != lastPermBlocker
        guard threeChanged || blockerChanged else { return }
        lastPermThree = nowThree
        lastPermBlocker = nowBlocker
        rebuildPermRow(threePermRow, ready: nowThree, hint: registry.threeFinger.permissionHint)
        rebuildPermRow(blockerPermRow, ready: nowBlocker, hint: registry.blocker.permissionHint)
        if (threeChanged && nowThree) || (blockerChanged && nowBlocker) {
            FeatureRegistry.shared.refresh()
        }
    }

    private func rebuildPermRow(_ rowView: NSStackView, ready: Bool, hint: String?) {
        rowView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let label = NSTextField(labelWithString: ready ? "权限已就绪" : (hint ?? "缺少权限"))
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = ready ? .secondaryLabelColor : .systemOrange
        rowView.addArrangedSubview(label)
        if !ready {
            let button = NSButton(title: "去授权…", target: self, action: #selector(openPermissionsFromHome(_:)))
            // tag 0=三指下滑（辅助功能+输入监控）；tag 1=防误触（仅辅助功能）
            button.tag = rowView === threePermRow ? 0 : 1
            button.bezelStyle = .rounded
            button.controlSize = .small
            rowView.addArrangedSubview(button)
        }
    }

    @objc private func openPermissionsFromHome(_ sender: NSButton) {
        _ = Permissions.requestAccessibility(prompt: true)
        if sender.tag == 0 {
            Permissions.requestListenEvent()
            Permissions.openListenEvent()
        }
        Permissions.openAccessibility()
    }

    @objc private func autoStartToggled(_ sender: NSSwitch) {
        Store.autoStart = sender.state == .on
        applyAutoStart(sender.state == .on)
    }

    @objc private func closeActionChanged(_ sender: NSPopUpButton) {
        if let value = sender.selectedItem?.representedObject as? Int {
            Store.closeAction = value
        }
    }

    /// 切换 Dock 图标显示：.regular 显示 / .accessory 隐藏（即时生效，无需重启）
    @objc private func dockVisibilityToggled(_ sender: NSSwitch) {
        let visible = sender.state == .on
        Store.dockVisible = visible
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
        NSLog("[TrackpadX] Dock 图标切换为 %@", visible ? "显示" : "隐藏")
    }

    private func applyAutoStart(_ enabled: Bool) {
        if enabled {
            do {
                try SMAppService.mainApp.register()
            } catch {
                NSLog("[TrackpadX] SMAppService 注册失败: \(error)")
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                NSLog("[TrackpadX] SMAppService 注销失败: \(error)")
            }
        }
    }
}

/// 输入时屏蔽触摸板（防误触）详情页
final class BlockerViewController: DetailViewController {
    private let feature: TouchpadBlockerFeature

    init(feature: TouchpadBlockerFeature) {
        self.feature = feature
        super.init(title: "输入时屏蔽触摸板")
    }

    required init?(coder: NSCoder) { fatalError("不支持 coder 初始化") }

    private let permissionRow = NSStackView()
    private var lastPermissionReady: Bool?

    override func viewDidLoad() {
        super.viewDidLoad()
        lastPermissionReady = feature.permissionReady

        let switchControl = NSSwitch()
        switchControl.state = Store.blockerEnabled ? .on : .off
        switchControl.target = self
        switchControl.action = #selector(enabledToggled(_:))
        stack.addArrangedSubview(row("启用功能", switchControl))
        stack.addArrangedSubview(caption("打字后的一小段时间内，忽略触控板引起的鼠标位移与滚动，避免打字时手掌误触。点击与拖拽不受影响（拖动窗口、文件等正常工作）。"))

        let popup = NSPopUpButton()
        let options: [(Double, String)] = [
            (0.2, "0.2 秒"), (0.3, "0.3 秒"), (0.5, "0.5 秒"), (0.7, "0.7 秒"), (1.0, "1.0 秒"),
        ]
        for (value, label) in options {
            popup.addItem(withTitle: label)
            popup.lastItem?.representedObject = value
        }
        if let current = options.first(where: { $0.0 == Store.blockerDelay }) {
            popup.selectItem(withTitle: current.1)
        }
        popup.target = self
        popup.action = #selector(delayChanged(_:))
        stack.addArrangedSubview(row("屏蔽间隔", popup))
        stack.addArrangedSubview(caption("打字结束后等待该时间，才恢复触摸板点击/滚动。"))

        // 权限行
        permissionRow.orientation = .horizontal
        permissionRow.alignment = .centerY
        permissionRow.spacing = 10
        stack.addArrangedSubview(permissionRow)
        rebuildPermissionRow()
    }

    /// 授权状态变化即重建权限行；授权到位时让 registry 同步启停服务
    override func permissionPollTick() {
        let now = feature.permissionReady
        guard now != lastPermissionReady else { return }
        let granted = now
        lastPermissionReady = now
        rebuildPermissionRow()
        if granted { FeatureRegistry.shared.refresh() }
    }

    private func rebuildPermissionRow() {
        permissionRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let status = feature.permissionReady
        let label = NSTextField(labelWithString: status ? "权限已就绪" : "缺少辅助功能权限")
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = status ? .secondaryLabelColor : .systemOrange
        permissionRow.addArrangedSubview(label)
        if !status {
            let button = NSButton(title: "打开辅助功能设置…", target: self, action: #selector(openPermission(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .small
            permissionRow.addArrangedSubview(button)
        }
    }

    @objc private func enabledToggled(_ sender: NSSwitch) {
        Store.blockerEnabled = sender.state == .on
    }

    @objc private func delayChanged(_ sender: NSPopUpButton) {
        if let value = sender.selectedItem?.representedObject as? Double {
            Store.blockerDelay = value
        }
    }

    @objc private func openPermission(_ sender: NSButton) {
        _ = Permissions.requestAccessibility(prompt: true)
        Permissions.openAccessibility()
    }
}

/// 三指下滑详情页
final class ThreeFingerViewController: DetailViewController {
    private let feature: ThreeFingerDownFeature

    init(feature: ThreeFingerDownFeature) {
        self.feature = feature
        super.init(title: "三指下滑")
    }

    required init?(coder: NSCoder) { fatalError("不支持 coder 初始化") }

    private let permissionRow = NSStackView()
    private var lastPermissionReady: Bool?

    override func viewDidLoad() {
        super.viewDidLoad()
        lastPermissionReady = feature.permissionReady

        let switchControl = NSSwitch()
        switchControl.state = Store.threeFingerEnabled ? .on : .off
        switchControl.target = self
        switchControl.action = #selector(enabledToggled(_:))
        stack.addArrangedSubview(row("启用功能", switchControl))
        stack.addArrangedSubview(caption("触控板三指下滑：最小化当前前台应用的聚焦窗口。"))

        // 全屏降级子选项（用户确认放置于此）
        let fallback = CustomRadioContainer()
        let noAction = NSButton(radioButtonWithTitle: "不动作", target: self, action: #selector(fallbackChanged(_:)))
        noAction.tag = 0
        let hideApp = NSButton(radioButtonWithTitle: "隐藏前台应用", target: self, action: #selector(fallbackChanged(_:)))
        hideApp.tag = 1
        fallback.addArrangedSubview(noAction)
        fallback.addArrangedSubview(hideApp)
        (Store.fullscreenFallback == 1 ? hideApp : noAction).state = .on
        stack.addArrangedSubview(row("全屏聚焦窗口无法最小化时", fallback))

        // 权限
        permissionRow.orientation = .horizontal
        permissionRow.alignment = .centerY
        permissionRow.spacing = 10
        permissionRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(permissionRow)
        rebuildPermissionRow()
    }

    /// 授权状态变化即重建权限行；授权到位时让 registry 同步启动手势监听
    override func permissionPollTick() {
        let now = feature.permissionReady
        guard now != lastPermissionReady else { return }
        let granted = now
        lastPermissionReady = now
        rebuildPermissionRow()
        if granted { FeatureRegistry.shared.refresh() }
    }

    private func rebuildPermissionRow() {
        permissionRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let label = NSTextField(labelWithString: feature.permissionReady ? "权限已就绪" : (feature.permissionHint ?? ""))
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = feature.permissionReady ? .secondaryLabelColor : .systemOrange
        permissionRow.addArrangedSubview(label)
        if !feature.permissionReady {
            let button = NSButton(title: "去授权…", target: self, action: #selector(openPermission(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .small
            permissionRow.addArrangedSubview(button)
        }
    }

    @objc private func enabledToggled(_ sender: NSSwitch) {
        Store.threeFingerEnabled = sender.state == .on
    }

    @objc private func fallbackChanged(_ sender: NSButton) {
        guard sender.state == .on else { return }
        Store.fullscreenFallback = sender.tag
    }

    @objc private func openPermission(_ sender: NSButton) {
        _ = Permissions.requestAccessibility(prompt: true)
        Permissions.requestListenEvent()
        Permissions.openAccessibility()
        Permissions.openListenEvent()
    }
}

private final class CustomRadioContainer: NSStackView {
    init() {
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = 12
    }

    required init?(coder: NSCoder) { fatalError("不支持 coder 初始化") }
}
