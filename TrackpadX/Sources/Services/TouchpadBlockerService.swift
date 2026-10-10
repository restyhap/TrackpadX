import AppKit
import ApplicationServices

/// 防误触：打字后一段时间内丢弃鼠标/滚轮事件
/// 迁移自 TouchpadBlocker（cghidEventTap 拦截型 tap + IME 全局监听备份）
final class TouchpadBlockerService {
    var delay: Double = 0.5

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var imeMonitor: Any?

    /// 待丢弃处理的键鼠事件类型
    private static let blockingMask: CGEventMask =
        (1 << CGEventType.mouseMoved.rawValue) |
        (1 << CGEventType.scrollWheel.rawValue) |
        (1 << CGEventType.leftMouseDown.rawValue) |
        (1 << CGEventType.rightMouseDown.rawValue) |
        (1 << CGEventType.otherMouseDown.rawValue) |
        (1 << CGEventType.leftMouseDragged.rawValue) |
        (1 << CGEventType.rightMouseDragged.rawValue) |
        (1 << CGEventType.otherMouseDragged.rawValue)

    /// 打字监测事件类型
    private static let typingMask: CGEventMask =
        (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.flagsChanged.rawValue)

    private static let networkingMask = blockingMask | typingMask

    func start() {
        guard tap == nil else { return }
        _ = Permissions.requestAccessibility(prompt: true)
        startTap()
        startIMEMonitor()
        NSLog("[TrackpadX] 拦截型服务已启动")
    }

    func stop() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            }
        }
        tap = nil
        runLoopSource = nil
        if let monitor = imeMonitor {
            NSEvent.removeMonitor(monitor)
            imeMonitor = nil
        }
        NSLog("[TrackpadX] 拦截型服务已停止")
    }

    private func startTap() {
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let service = userInfoPointer(TouchpadBlockerService.self, userInfo) else {
                return Unmanaged.passUnretained(event)
            }
            guard let result = service.handle(event: event, type: type) else { return nil }
            return Unmanaged.passUnretained(result)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.networkingMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            NSLog("[TrackpadX] 创建 cghidEventTap 失败（辅助功能权限？）")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// tap 回调：打字类事件记录时间，鼠标/滚轮类在屏蔽窗口内返回 nil 丢弃
    func handle(event: CGEvent, type: CGEventType) -> CGEvent? {
        // 系统因超时禁用 tap，需要恢复
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return event
        }

        switch type {
        case .keyDown, .flagsChanged:
            recordTyping()
            return event
        default:
            break
        }

        guard isBlockingEvent(type) else { return event }
        let sinceTyping = Date().timeIntervalSince(lastTypingDate)
        if sinceTyping < delay {
            return nil // 屏蔽窗口内丢弃误触
        }
        return event
    }

    private var lastTypingDate: Date = .distantPast

    private func recordTyping() {
        lastTypingDate = Date()
    }

    private func isBlockingEvent(_ type: CGEventType) -> Bool {
        (Self.blockingMask >> UInt64(type.rawValue)) & 1 == 1
    }

    /// 中文输入法下 keyDown 可能变形，增加全局监听备份通道
    /// 只读事件用于更新打字时间，不做修改（global monitor 本就无法修改）
    private func startIMEMonitor() {
        imeMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .flagsChanged],
            handler: { [weak self] _ in
                self?.recordTyping()
            })
    }
}

private func userInfoPointer<T: AnyObject>(_ type: T.Type, _ userInfo: UnsafeMutableRawPointer?) -> T? {
    guard let userInfo = userInfo else { return nil }
    return Unmanaged<T>.fromOpaque(userInfo).takeUnretainedValue()
}
