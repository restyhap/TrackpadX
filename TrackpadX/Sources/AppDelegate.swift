import AppKit

@objc(TrackpadXAppDelegate) // NSPrincipalClass 经 NSClassFromString 查找, 需暴露 ObjC 名
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[TrackpadX] 1 didFinishLaunching 开始")
        NSApp.setActivationPolicy(Store.dockVisible ? .regular : .accessory)
        NSLog("[TrackpadX] 2 policy set (dockVisible=%@)", Store.dockVisible ? "true" : "false")
        installMainMenu()
        NSLog("[TrackpadX] 3 menu installed, ms=\(Int(CACurrentMediaTime()*1000))")
        FeatureRegistry.shared.start()
        NSLog("[TrackpadX] 4 registry started, ms=\(Int(CACurrentMediaTime()*1000))")

        // 系统会在注销/重启时自动恢复"重启前在运行"的 app（relaunch on login）。
        // 本 app 经 SMAppService 登录项启动，官方建议禁用该恢复机制避免双通道拉起窗口（AppKit 头文件建议）。
        NSApp.disableRelaunchOnLogin()

        let isLoginLaunch = Self.isLaunchedAsLoginItem(notification: notification)
        NSLog("[TrackpadX] 4.5 登录启动检测: \(isLoginLaunch)")

        // 窗口构建段整体包裹 ObjC 异常捕获（AppKit 会吞 delegate 回调里的异常导致静默截断）
        txCatchObjCException({
            let controller = SettingsWindowController()
            self.windowController = controller
            if isLoginLaunch {
                // 开机/登录自启：后台静默运行，不显示窗口也不抢占焦点；
                // 用户点 Dock 图标或从启动台/Spotlight 重新打开时经 handleReopen 唤回设置窗。
                NSLog("[TrackpadX] 6 登录启动: 后台静默, 不显示窗口")
            } else {
                controller.window?.center()
                controller.window?.makeKeyAndOrderFront(nil)
                controller.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
                let f = controller.window?.frame ?? .zero
                NSLog("[TrackpadX] 6 window frame=\(f) visible=\(controller.window?.isVisible ?? false) count=\(NSApp.windows.count)")
            }
            installCloseHandler(for: controller.window)
        }) { ex in
            NSLog("[TrackpadX] ❌ 窗口构建异常: \(ex.name.rawValue) - \(String(describing: ex.reason)) userInfo=\(String(describing: ex.userInfo))")
        }
        NSLog("[TrackpadX] 7 启动完成")
    }

    /// 登录项启动检测（仅用精确信号）：
    /// SMAppService 登录项启动会下发 kAEOpenApplication Apple Event，
    /// 且 propData 参数为 keyAELaunchedAsLogInItem（'lgin'）。
    /// 不用 NSApplication.launchIsDefaultUserInfoKey 做次级信号——实测有误伤：
    /// AppKit 头文件注明"app 带有待恢复的窗口状态"时该值也为 false（崩溃/被杀残留同理），
    /// 会把手动启动误判为登录启动导致不弹窗（v0.2.3 实机日志证据）。系统恢复路径由 disableRelaunchOnLogin 兜住。
    private static func isLaunchedAsLoginItem(notification: Notification) -> Bool {
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication,
           event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            NSLog("[TrackpadX] 登录启动信号命中: AppleEvent 'lgin'")
            return true
        }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 点击关闭按钮时的行为：0=直接退出；1=保留进程后台运行（仅收起窗口）
        let result = Store.closeAction != 1
        NSLog("[TrackpadX] 最后窗口关闭: closeAction=\(Store.closeAction) → terminate=\(result)")
        return result
    }

    /// 关闭主窗口后的分流（macOS 27 实测 applicationShouldTerminateAfterLastWindowClosed 不被调用，
    /// 以 willCloseNotification 为准；terminate 用 async 避免在关闭通知内重入）
    private func installCloseHandler(for window: NSWindow?) {
        guard let window else { return }
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                guard let self, !isTerminatingManually else { return }
                if Store.closeAction == 1 {
                    NSLog("[TrackpadX] 窗口已关闭: 后台运行 (closeAction=1)")
                } else {
                    NSLog("[TrackpadX] 窗口已关闭: 直接退出 (closeAction=0)")
                    isTerminatingManually = true
                    DispatchQueue.main.async { NSApp.terminate(nil) }
                }
            }
    }

    /// 处理 terminate 期间窗口链式 willClose 的重入
    private var isTerminatingManually = false

    /// 后台模式下点击 Dock 图标重新打开设置窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowController?.showWindow(nil)
            windowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    /// 最小主菜单（保证 ⌘Q 可用）
    private func installMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "TrackpadX")
        appMenu.addItem(NSMenuItem(title: "退出 TrackpadX", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }
}
