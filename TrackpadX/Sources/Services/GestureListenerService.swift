import AppKit

/// 全局手势监听：session 层 listen-only tap，收集手势期间每根手指的 NSTouch，
/// 交给 ThreeFingerDownRecognizer 状态机判定（迁移自 01/02 文档路线 A，参考 AltTab 实践）
final class GestureListenerService {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// 监听的手势事件族（gesture/begin/end + magnify/rotate/swipe 属于同一 gesture 驱动族，
    /// 覆盖 widest 的 mask 保证 NSEvent 上可取到 allTouches 的原始手势事件）
    private static let gestureMask: CGEventMask =
        (1 << CGEventType(rawValue: 29)!.rawValue) | // NSEventTypeGesture
        (1 << CGEventType(rawValue: 30)!.rawValue) | // NSEventTypeBeginGesture
        (1 << CGEventType(rawValue: 31)!.rawValue) | // NSEventTypeEndGesture
        (1 << CGEventType(rawValue: 32)!.rawValue) | // NSEventTypeSwipe
        (1 << CGEventType(rawValue: 19)!.rawValue) | // NSEventTypeMagnify
        (1 << CGEventType(rawValue: 21)!.rawValue)   // NSEventTypeRotate

    private let recognizer = ThreeFingerDownRecognizer()

    func start() {
        guard tap == nil else { return }
        if Permissions.listenEvent == .denied {
            Permissions.requestListenEvent()
            return
        }
        startTap()
        NSLog("[TrackpadX] 手势监听已启动")
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
        recognizer.reset()
        NSLog("[TrackpadX] 手势监听已停止")
    }

    private func startTap() {
        // 注意：C 回调里不能捕获 Swift 上下文，用 userInfo 传 self；
        // NSEvent(cgEvent:) 必须在主线程构造（AltTab 实证：否则 AppKit 崩溃），
        // 所以回调里只把 cgEvent 转发到主线程队列。
        let callback: CGEventTapCallBack = { _, _, event, userInfo in
            let service = Unmanaged<GestureListenerService>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                service.delivery(event: Unmanaged.passUnretained(event).takeUnretainedValue())
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.gestureMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            NSLog("[TrackpadX] 创建手势 listen-only tap 失败（输入监控权限？）")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// 主线程入口：从 CGEvent 构造 NSEvent 并提取触碰集合
    private func delivery(event cgEvent: CGEvent) {
        // type 30 (NSEventTypeGesture) 在 macOS 27 上被 AppKit 判为 unrecognized 类型，
        // 构造 NSEvent 会刷 "unrecognized type is 30" 警告；其 fingers 数据
        // 与 phase=.any 由 Begin/End 驱动的连续 event 同源，直接跳过构造避免刷屏
        if cgEvent.type.rawValue == 30 { return }
        // NSEvent(cgEvent:) 对部分事件会抛 ObjC 断言异常（AppKit 认为事件不完整/不可转换），
        // 该构造是非失败模式，Swift 层捕获不了，曾致整条进程 SIGABRT（用户实测崩溃报告）；
        // 用 ObjC 垫片包住，异常时仅丢弃该事件，功能不受影响
        var capturedEvent: NSEvent?
        var exceptionName: String?
        txCatchObjCException({
            capturedEvent = NSEvent(cgEvent: cgEvent)
        }, { exception in
            exceptionName = exception.name.rawValue
        })
        guard let nsEvent = capturedEvent else {
            if let name = exceptionName {
                NSLog("[TrackpadX] NSEvent 构造异常已丢弃事件 (type=%d, exception=%@)", cgEvent.type.rawValue, name as NSString)
            }
            return
        }
        let touches = nsEvent.allTouches()
        guard !touches.isEmpty else { return }
        // Universal Control 间接触摸访问 normalizedPosition 会抛 ObjC 异常（Swift 捕获不了），
        // safePosition 垫片已兜住，直接交给识别器逐点防护读取
        recognizer.update(with: touches)
    }
}
