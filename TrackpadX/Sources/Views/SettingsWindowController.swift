import AppKit
import ServiceManagement

/// 设置主窗口（方案 A）：左列功能清单，右侧为选中功能的分支详情
final class SettingsWindowController: NSWindowController {
    private let registry = FeatureRegistry.shared

    private var sidebarStack: NSStackView!
    private var detailContainer: NSView!
    private var currentDetail: NSViewController?
    private var defaultsObserver: NSObjectProtocol?
    private var selectedIndex = 0

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "触摸板扩展"
        window.isReleasedWhenClosed = false
        // 关闭窗口状态恢复：避免系统重启后经恢复机制自动弹出设置窗口
        window.isRestorable = false
        super.init(window: window)
        buildContent()
        selectItem(0)
        defaultsObserver = Store.observeDefaults { [weak self] in self?.refreshSidebar() }
    }

    required init?(coder: NSCoder) { fatalError("不支持 coder 初始化") }

    deinit {
        if let observer = defaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - 构建

    private func buildContent() {
        guard let content = window?.contentView else { return }

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(split)
        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            split.topAnchor.constraint(equalTo: content.topAnchor),
            split.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        // 左列
        sidebarStack = NSStackView()
        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 4
        // NSStackView 非 flipped，直接作 documentView 时内容会贴到滚动区底部；
        // 包一层翻转坐标的容器并锚顶，让侧栏行从最上方排布
        let sidebarFlipped = FlippedContainerView()
        sidebarFlipped.translatesAutoresizingMaskIntoConstraints = false
        sidebarFlipped.addSubview(sidebarStack)
        let sidebarScroll = NSScrollView()
        sidebarScroll.documentView = sidebarFlipped
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.translatesAutoresizingMaskIntoConstraints = false
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sidebarStack.topAnchor.constraint(equalTo: sidebarFlipped.topAnchor),
            sidebarStack.leadingAnchor.constraint(equalTo: sidebarFlipped.leadingAnchor),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebarFlipped.trailingAnchor),
            sidebarStack.bottomAnchor.constraint(equalTo: sidebarFlipped.bottomAnchor),
            sidebarFlipped.topAnchor.constraint(equalTo: sidebarScroll.contentView.topAnchor),
            sidebarFlipped.leadingAnchor.constraint(equalTo: sidebarScroll.contentView.leadingAnchor),
            sidebarFlipped.trailingAnchor.constraint(equalTo: sidebarScroll.contentView.trailingAnchor),
            sidebarFlipped.widthAnchor.constraint(equalTo: sidebarScroll.contentView.widthAnchor),
            sidebarFlipped.heightAnchor.constraint(greaterThanOrEqualTo: sidebarScroll.contentView.heightAnchor),
        ])
        split.addArrangedSubview(sidebarScroll)
        split.setHoldingPriority(NSLayoutConstraint.Priority(260), forSubviewAt: 0)
        sidebarScroll.widthAnchor.constraint(equalToConstant: 230).isActive = true

        // 右侧
        detailContainer = NSView()
        split.addArrangedSubview(detailContainer)

        refreshSidebar()
    }

    // MARK: - 左列

    private struct Entry {
        let title: String
        let symbol: String
        let makeDetail: () -> NSViewController
    }

    private func entries() -> [Entry] {
        let threeFinger = registry.threeFinger
        let blocker = registry.blocker
        return [
            Entry(title: "通用", symbol: "gearshape") { GeneralViewController() },
            Entry(title: "三指下滑", symbol: "hand.draw") { ThreeFingerViewController(feature: threeFinger) },
            Entry(title: "输入时屏蔽触摸板", symbol: "keyboard") { BlockerViewController(feature: blocker) },
        ]
    }

    private func refreshSidebar() {
        guard let stack = sidebarStack else { return }
        let list = entries()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, entry) in list.enumerated() {
            let button = SidebarRowButton(title: entry.title, symbolName: entry.symbol)
            button.isRowSelected = index == selectedIndex
            button.tag = index
            button.target = self
            button.action = #selector(sidebarClicked(_:))
            button.translatesAutoresizingMaskIntoConstraints = false
            // 先加入 stack 层级，再激活约束（先激活会因无共同祖先抛 NSGenericException，被 AppKit 吞掉导致窗口静默消失）
            stack.addArrangedSubview(button)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -12),
                button.heightAnchor.constraint(equalToConstant: 34),
            ])
        }
    }

    @objc private func sidebarClicked(_ sender: NSButton) {
        selectItem(sender.tag)
    }

    // documentView 必须是 flipped 坐标系，内容才从顶部排布
    private final class FlippedContainerView: NSView {
        override var isFlipped: Bool { true }
    }

    // MARK: - 右侧

    func selectItem(_ index: Int) {
        selectedIndex = index
        let item = entries()[index]

        currentDetail?.view.removeFromSuperview()
        currentDetail = nil
        let detail = item.makeDetail()
        currentDetail = detail
        detailContainer.addSubview(detail.view)
        detail.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            detail.view.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            detail.view.bottomAnchor.constraint(equalTo: detailContainer.bottomAnchor),
            detail.view.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            detail.view.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
        ])
        refreshSidebar()
    }
}

/// 左列行按钮（仿系统设置侧栏观感）
final class SidebarRowButton: NSButton {
    /// 选中态（自定义绘制背景）
    var isRowSelected: Bool = false {
        didSet { setDefaultBackground() }
    }

    init(title: String, symbolName: String) {
        super.init(frame: .zero)
        self.title = title
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        imagePosition = .imageLeading
        imageHugsTitle = true
        bezelStyle = .regularSquare
        isBordered = false
        contentTintColor = .labelColor
        font = NSFont.systemFont(ofSize: 13)
        wantsLayer = true
        setDefaultBackground()
    }

    required init?(coder: NSCoder) { fatalError("不支持 coder 初始化") }

    private func setDefaultBackground() {
        if isRowSelected {
            layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.85).cgColor
            layer?.cornerRadius = 6
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.cornerRadius = 6
        }
    }
}
