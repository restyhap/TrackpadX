import AppKit

@objc(TrackpadXAppDelegate) // NSPrincipalClass 经 NSClassFromString 查找, 需暴露 ObjC 名
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[TrackpadX] 1 didFinishLaunching 开始")
        NSApp.setActivationPolicy(.regular)
        NSLog("[TrackpadX] 2 policy set")
        installMainMenu()
        NSLog("[TrackpadX] 3 menu installed, ms=\(Int(CACurrentMediaTime()*1000))")
        FeatureRegistry.shared.start()
        NSLog("[TrackpadX] 4 registry started, ms=\(Int(CACurrentMediaTime()*1000))")

        // 窗口构建段整体包裹 ObjC 异常捕获（AppKit 会吞 delegate 回调里的异常导致静默截断）
        txCatchObjCException({
            let controller = SettingsWindowController()
            self.windowController = controller
            controller.window?.center()
            controller.window?.makeKeyAndOrderFront(nil)
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            let f = controller.window?.frame ?? .zero
            NSLog("[TrackpadX] 6 window frame=\(f) visible=\(controller.window?.isVisible ?? false) count=\(NSApp.windows.count)")
            installCloseHandler(for: controller.window)
        }) { ex in
            NSLog("[TrackpadX] ❌ 窗口构建异常: \(ex.name.rawValue) - \(String(describing: ex.reason)) userInfo=\(String(describing: ex.userInfo))")
        }
        NSLog("[TrackpadX] 7 启动完成")
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
