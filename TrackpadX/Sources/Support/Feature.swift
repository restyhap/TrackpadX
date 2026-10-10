import AppKit
import ApplicationServices

/// 单个功能（Feature）描述：设置列表的插槽协议
@objc protocol FeatureActions: AnyObject {
    // 由各详情控制器实现
}

protocol FeatureItem {
    var id: String { get }
    var title: String { get }
    var symbolName: String { get }
    /// 当前是否可用（功能开 + 权限齐）
    var isActive: Bool { get }
    /// 权限是否全部就绪
    var permissionReady: Bool { get }
    /// 缺失权限的描述（用于列表黄标提示）
    var permissionHint: String? { get }
    func makeViewController() -> NSViewController
}

/// 防误触（输入时屏蔽触摸板）
final class TouchpadBlockerFeature: FeatureItem {
    let id = "blocker"
    let title = "输入时屏蔽触摸板"
    let symbolName = "keyboard"

    init() {}

    var permissionReady: Bool { Permissions.accessibility == .granted }
    var permissionHint: String? { permissionReady ? nil : "需要辅助功能权限" }

    var isActive: Bool { Store.blockerEnabled && permissionReady }

    func makeViewController() -> NSViewController { BlockerViewController(feature: self) }
}

/// 三指下滑最小化前台聚焦窗口
final class ThreeFingerDownFeature: FeatureItem {
    let id = "threeFingerDown"
    let title = "三指下滑"
    let symbolName = "hand.draw"

    init() {}

    var permissionReady: Bool {
        Permissions.accessibility == .granted && Permissions.listenEvent == .granted
    }

    var permissionHint: String? {
        if permissionReady { return nil }
        var missing: [String] = []
        if Permissions.accessibility == .denied { missing.append("辅助功能") }
        if Permissions.listenEvent == .denied { missing.append("输入监控") }
        return "需要：" + missing.joined(separator: "、")
    }

    var isActive: Bool { Store.threeFingerEnabled && permissionReady }

    func makeViewController() -> NSViewController { ThreeFingerViewController(feature: self) }
}

/// 注册表：持有全部 Feature 与服务，按存储状态启停
final class FeatureRegistry {
    static let shared = FeatureRegistry()

    let blocker = TouchpadBlockerFeature()
    let threeFinger = ThreeFingerDownFeature()

    private var observer: NSObjectProtocol?
    private var blockerService: TouchpadBlockerService?
    private var gestureListener: GestureListenerService?

    var items: [FeatureItem] { [blocker, threeFinger] }

    func start() {
        observer = Store.observeDefaults { [weak self] in self?.refresh() }
        refresh()
    }

    func refresh() {
        // 防误触
        let blockerOn = Store.blockerEnabled && Store.blockerDelay > 0
        if blockerOn {
            if blockerService == nil {
                let service = TouchpadBlockerService()
                service.start()
                blockerService = service
            } else {
                blockerService?.delay = Store.blockerDelay
            }
        } else if let service = blockerService {
            service.stop()
            blockerService = nil
        }

        // 三指下滑
        let threeOn = Store.threeFingerEnabled && Permissions.listenEvent == .granted
        if threeOn {
            if gestureListener == nil {
                let listener = GestureListenerService()
                listener.start()
                gestureListener = listener
            }
        } else if let listener = gestureListener {
            listener.stop()
            gestureListener = nil
        }
    }
}
