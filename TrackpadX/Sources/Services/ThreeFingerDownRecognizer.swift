import AppKit
import ApplicationServices

/// 三指下滑状态机：接触数为 3 → 质心竖直向下位移越阈值 → 结束时触发一次（冷却防重）
/// 防护：NSTouch.normalizedPosition 对 Universal Control 间接触摸可能抛 ObjC 异常，
/// 通过 txCatchObjCException 垫片（ObjC/@try）安全读取，异常视为无效触碰丢弃。
final class ThreeFingerDownRecognizer {

    struct Finger {
        let identity: String
        let position: CGPoint
        let isEnded: Bool
    }

    /// 归一化坐标中的手指集合：identity -> Finger
    private var fingers: [String: Finger] = [:]

    /// 三指成立的起始质心
    private var startCentroid: CGPoint?

    /// 上一次触发时间，冷却窗口内不再触发
    private var lastFired: Date = .distantPast

    static let cooldown: TimeInterval = 0.6
    /// 下滑的最小竖直位移（归一化单位，实机调参；原型验证时会输出日志校准方向）
    static let thresholdY: CGFloat = 0.12
    /// 水平位移超过竖直位移的该比例时视为非下滑
    static let maxXRatio: CGFloat = 0.6

    func update(with touches: Set<NSTouch>) {
        var next: [String: Finger] = [:]
        for touch in touches {
            guard let position = safePosition(of: touch) else { continue }
            let key = String(describing: touch.identity)
            let ended = touch.phase.contains(.ended) || touch.phase.contains(.cancelled)
            next[key] = Finger(identity: key, position: position, isEnded: ended)
        }
        guard !next.isEmpty else {
            if !fingers.isEmpty {
                // 触碰集合为空 = 所有手指已离开，手势终止
                if startCentroid != nil { evaluateEnd() }
                reset()
            }
            return
        }

        let touching = next.values.filter { !$0.isEnded }
        let count = touching.count

        if startCentroid == nil {
            // 首次形成三指接触：记录起始质心
            if count == 3 {
                startCentroid = centroid(touching)
                fingers = next
            }
            return
        }

        if count == 3 {
            fingers = next
        } else if count < 3 {
            // 手数变化 → 手势结束，评估触发
            evaluateEnd()
            reset()
        } else {
            // 升到 4+ 指：取消识别
            reset()
        }
    }

    /// 向下位移越阈值 → 触发一次最小化
    private func evaluateEnd() {
        guard let start = startCentroid else { return }
        let snapshot = Array(fingers.values)
        guard snapshot.count >= 3 else { return }
        let current = centroid(snapshot)
        let dy = current.y - start.y
        let dx = abs(current.x - start.x)

        let now = Date()
        guard now.timeIntervalSince(lastFired) > Self.cooldown else { return }
        guard abs(dy) >= Self.thresholdY, dx <= abs(dy) * Self.maxXRatio else {
            NSLog("[TrackpadX] 手势采样未达阈值 dy=%.4f dx=%.4f", Double(dy), Double(dx))
            return
        }

        lastFired = now
        if dy < 0 {
            NSLog("[TrackpadX] 触发三指下滑 (dy=%.4f)", Double(dy))
            MinimizeWindowService.shared.performMinimize()
        } else {
            NSLog("[TrackpadX] 质心上滑 dy=%.4f，预留不触发", Double(dy))
        }
    }

    private func centroid(_ fingerList: [Finger]) -> CGPoint {
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for finger in fingerList {
            sumX += finger.position.x
            sumY += finger.position.y
        }
        let count = CGFloat(max(fingerList.count, 1))
        return CGPoint(x: sumX / count, y: sumY / count)
    }

    /// 间接触摸防护：ObjC 垫片读取 normalizedPosition，异常返回 nil
    private func safePosition(of touch: NSTouch) -> CGPoint? {
        var result: CGPoint?
        txCatchObjCException({
            result = touch.normalizedPosition
        }, { exception in
            NSLog("[TrackpadX] 间接触摸 normalizedPosition 异常：%@", exception.name.rawValue)
        })
        return result
    }

    func reset() {
        fingers = [:]
        startCentroid = nil
    }
}
