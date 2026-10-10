import Foundation
import AppKit

/// 用户可配置的持久化存储（standard 域；声明 suiteName=自身 bundle id 会被 UserDefaults 拒绝返回 nil）
enum Store {
    static let suite = UserDefaults.standard

    enum Key: String {
        case blockerEnabled = "feature.blocker.enabled"
        case blockerDelay = "feature.blocker.delay"
        case threeFingerEnabled = "feature.threefinger.enabled"
        case fullscreenFallback = "feature.threefinger.fullscreenFallback" // 0=不动作 1=隐藏App
        case autoStart = "general.autostart"
        case closeAction = "general.closeAction" // 0=直接退出（默认） 1=后台运行
        case dockVisible = "general.dockVisible" // Dock 图标显示开关（默认显示）
    }

    static var blockerEnabled: Bool {
        get { suite.object(forKey: Key.blockerEnabled.rawValue) as? Bool ?? true }
        set { suite.set(newValue, forKey: Key.blockerEnabled.rawValue) }
    }

    static var blockerDelay: Double {
        get { suite.object(forKey: Key.blockerDelay.rawValue) as? Double ?? 0.5 }
        set { suite.set(newValue, forKey: Key.blockerDelay.rawValue) }
    }

    static var threeFingerEnabled: Bool {
        get { suite.object(forKey: Key.threeFingerEnabled.rawValue) as? Bool ?? false }
        set { suite.set(newValue, forKey: Key.threeFingerEnabled.rawValue) }
    }

    /// 0 = 全屏时不动作（默认）；1 = 降级为隐藏前台应用
    static var fullscreenFallback: Int {
        get { suite.object(forKey: Key.fullscreenFallback.rawValue) as? Int ?? 0 }
        set { suite.set(newValue, forKey: Key.fullscreenFallback.rawValue) }
    }

    static var autoStart: Bool {
        get { suite.object(forKey: Key.autoStart.rawValue) as? Bool ?? false }
        set { suite.set(newValue, forKey: Key.autoStart.rawValue) }
    }

    /// 关闭行为：0 = 点击关闭直接退出（默认）；1 = 关闭后保留进程后台运行（Dock 点击可重新打开窗口）
    static var closeAction: Int {
        get { suite.object(forKey: Key.closeAction.rawValue) as? Int ?? 0 }
        set { suite.set(newValue, forKey: Key.closeAction.rawValue) }
    }

    /// Dock 栏图标显示（true=显示默认；false=运行时切 accessory 隐藏，重新打开 app 仍可唤回设置窗）
    static var dockVisible: Bool {
        get { suite.object(forKey: Key.dockVisible.rawValue) as? Bool ?? true }
        set { suite.set(newValue, forKey: Key.dockVisible.rawValue) }
    }

    static func observeDefaults(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: suite,
            queue: .main,
            using: { _ in handler() })
    }
}

/// 权限预检与系统设置深链
enum Permissions {
    case granted
    case denied

    static var accessibility: Permissions {
        AXIsProcessTrusted() ? .granted : .denied
    }

    /// 引导弹窗：true = 弹系统授权页
    static func requestAccessibility(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static var listenEvent: Permissions {
        CGPreflightListenEventAccess() ? .granted : .denied
    }

    static func requestListenEvent() {
        _ = CGRequestListenEventAccess()
    }

    /// 打开系统设置对应权限面板
    static func open(panel anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    static func openAccessibility() { open(panel: "Privacy_Accessibility") }
    static func openListenEvent() { open(panel: "Privacy_ListenEvent") }
}
