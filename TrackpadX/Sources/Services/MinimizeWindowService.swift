import AppKit
import ApplicationServices

/// 通过 AX API 最小化当前前台应用的聚焦窗口
/// 路径：frontmostApplication → AXUIElementCreateApplication → kAXFocusedWindowAttribute
///       → AXUIElementPerformAction("AXMinimize")
/// 失败时按用户设置降级：不动作（默认）或隐藏前台应用
final class MinimizeWindowService {
    static let shared = MinimizeWindowService()

    /// kAXMinimizeWindowAction（AXActions.h）的 Swift 模块内未桥接，显式定义（公开常量）
    private static let minimizeAction = "AXMinimize" as CFString
    /// kAXMinimizedAttribute：窗口"已最小化"数据开关（与最小化按钮同源），写 TRUE 等价按钮按下
    private static let minimizedAttribute = "AXMinimized" as CFString
    private static let focusedWindow = kAXFocusedWindowAttribute as CFString
    private static let mainWindow = kAXMainWindowAttribute as CFString
    private static let windowsList = kAXWindowsAttribute as CFString
    /// 窗口全屏状态（Swift 模块内未桥接，显式定义）
    private static let fullscreenFlag = "AXFullScreen" as CFString

    private init() {}

    func performMinimize() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            NSLog("[TrackpadX] 无前台应用")
            return
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var window: AXUIElement?
        var path = "无"

        // 1) 聚焦窗口
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, Self.focusedWindow, &value) == .success,
           let w = value as! AXUIElement? {
            window = w
            path = "focusedWindow"
        }

        // 2) 聚焦窗口缺失（应用无可聚焦窗口等）→ 主窗口
        if window == nil,
           AXUIElementCopyAttributeValue(axApp, Self.mainWindow, &value) == .success,
           let w = value as! AXUIElement? {
            window = w
            path = "mainWindow"
        }

        // 3) 主窗口也缺失 → 窗口列表第一项
        if window == nil,
           AXUIElementCopyAttributeValue(axApp, Self.windowsList, &value) == .success,
           let list = value as? NSArray, list.count > 0 {
            window = (list[0] as! AXUIElement)
            path = "windows[0]"
        }

        guard let target = window else {
            degrade(app: app, reason: "无可操作的窗口")
            return
        }

        // 全屏聚焦窗口提前分流：AX 动作层/属性层均会失败，而合成 ⌘M 会落在
        // 无可执行菜单项的 app 上触发系统提示音（用户实测"响一声"）。
        // 直接按用户设置的降级策略处理（不动作 / 隐藏前台应用）
        var fsValue: CFTypeRef?
        let fs = AXUIElementCopyAttributeValue(target, Self.fullscreenFlag, &fsValue)
        if fs == .success, (fsValue as? NSNumber)?.boolValue == true {
            degrade(app: app, reason: "全屏聚焦窗口无法最小化")
            return
        }

        // 取证: 目标窗口的角色/动作清单, 便于诊断 err=-25205 (ActionUnsupported)
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(target, kAXRoleAttribute as CFString, &role)
        var actionsCF: CFArray?
        if AXUIElementCopyActionNames(target, &actionsCF) == .success, let names = actionsCF as? [String] {
            NSLog("[TrackpadX] 目标窗口 app=%@ path=%@ role=%@ 动作清单=%@", app.localizedName ?? "?", path, (role as? String) ?? "?", names.joined(separator: ","))
        }

        let result = AXUIElementPerformAction(target, Self.minimizeAction)
        if result == .success {
            NSLog("[TrackpadX] 已最小化 %@ 的聚焦窗口（动作层）", app.localizedName ?? "?")
            return
        }

        // 动作层失败（部分 app 未注册 AXMinimize 动作，仅注册 AXRaise 等）
        // → 属性层兜底：写 kAXMinimizedAttribute=TRUE（与最小化按钮同源），带重试验证
        if tryAttributeMinimize(target, app: app) {
            NSLog("[TrackpadX] 已通过 AXMinimized 属性置位最小化 %@（动作层 err=%d）", app.localizedName ?? "?", result.rawValue)
            return
        }
        // 属性层也不稳定（ Electron/Tauri 系 AX 桥异步、置位成功但未应用）
        // → 键盘层兜底：向前台合成 ⌘M（最小化快捷键），直发版无沙盒可行
        if tryKeyboardMinimize(pid: app.processIdentifier) {
            NSLog("[TrackpadX] 已通过合成 ⌘M 最小化 %@（AX 双层均未应用）", app.localizedName ?? "?")
            return
        }
        degrade(app: app, reason: "最小化动作失败（err=\(result.rawValue)）")
    }

    /// 全屏等不可最小化场景：按用户设置的降级策略
    private func degrade(app: NSRunningApplication, reason: String) {
        if Store.fullscreenFallback == 1 {
            NSLog("[TrackpadX] %@，按设置降级为隐藏前台应用", reason)
            app.hide()
        } else {
            NSLog("[TrackpadX] %@，按默认策略不动作", reason)
        }
    }

    // MARK: - 属性层兜底（带重试验证，对抗 AX 异步桥）

    /// 写 TRUE 后复读校验；Electron/Tauri 桥可能返回成功但未及时应用 → 3 次重试
    private func tryAttributeMinimize(_ target: AXUIElement, app: NSRunningApplication) -> Bool {
        for attempt in 1...3 {
            let setResult = AXUIElementSetAttributeValue(target, Self.minimizedAttribute, kCFBooleanTrue as CFTypeRef)
            guard setResult == .success else {
                NSLog("[TrackpadX] 属性置位 attempt=%d set err=%d", attempt, setResult.rawValue)
                continue
            }
            // 置位是异步应用，稍候复读验证真实状态
            usleep(useconds_t(80_000 * UInt32(attempt) + 40_000))
            var value: CFTypeRef?
            let read = AXUIElementCopyAttributeValue(target, Self.minimizedAttribute, &value)
            if read == .success, let flag = (value as? NSNumber)?.boolValue, flag {
                NSLog("[TrackpadX] 属性置位验证通过 attempt=%d", attempt)
                return true
            }
            NSLog("[TrackpadX] 属性置位未生效 attempt=%d read=%d val=%@", attempt, read.rawValue, String(describing: value as? Bool ?? false))
        }
        return false
    }

    // MARK: - 键盘层兜底（合成 ⌘M）

    /// AX 双层都不通时，向前台发最小化快捷键（需要辅助功能权限，直发无沙盒可行）
    /// 必须验证生效：部分 app 无可执行的"最小化"菜单项，无效 ⌘M 会触发系统提示音，
    /// 此前无条件返回 true 会吞掉后续降级动作（"隐藏前台应用"从未被执行）
    private func tryKeyboardMinimize(pid: pid_t) -> Bool {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 46, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 46, keyDown: false)
        else { return false }
        let before = visibleWindowNumbers(pid)
        down.flags = [.maskCommand]
        up.flags = [.maskCommand]
        down.post(tap: .cgSessionEventTap)
        usleep(30_000)
        up.post(tap: .cgSessionEventTap)
        // 给 Dock 最小化动画留时间，再看目标进程是否有窗口从屏上消失
        usleep(150_000)
        let removed = visibleWindowNumbers(pid).subtracting(before)
        if removed.isEmpty {
            NSLog("[TrackpadX] 合成 ⌘M 后无窗口消失（无可执行菜单项，伴系统提示音），转入降级")
            return false
        }
        return true
    }

    /// 目标进程当前在屏幕上的窗口号集合（CGWindow 公开 API，验证最小化是否实际生效）
    private func visibleWindowNumbers(_ pid: pid_t) -> Set<Int> {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var out = Set<Int>()
        for w in list where (w["kCGWindowOwnerPID"] as? Int32) == pid {
            if let n = w["kCGWindowNumber"] as? Int { out.insert(n) }
        }
        return out
    }
}
