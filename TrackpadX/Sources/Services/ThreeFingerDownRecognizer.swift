import AppKit
import ApplicationServices

/// 三指下滑状态机 v2：三指接触成立后，要求**三根手指全部真实向下位移**且位移彼此
/// 相近（离散度受限）才触发最小化——纯质心判定会被"两指下滑 + 单指静止误触"误触发
/// （质心被两根下滑手指拉低，但静止指毫无位移），v2 的逐指判定天然排除该场景。
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

    /// 三指成立时每根手指的起始 y（identity -> y）
    private var startPositions: [String: CGFloat] = [:]

    /// 三指成立时的质心 x（用于水平位移判定）
    private var centroidXStart: CGFloat = 0

    /// 上一次触发时间，冷却窗口内不再触发
    private var lastFired: Date = .distantPast

    static let cooldown: TimeInterval = 0.6
    /// 单指真实下滑的最小竖直位移（严格路径 A：逐指绝对阈值）
    static let perFingerThresholdY: CGFloat = 0.08
    /// 二指主导路径 B：主拉手指的最小竖直位移（第三指允许静止/微小位移）
    static let mainFingerThresholdY: CGFloat = 0.15
    /// 三指位移一致性约束（路径 A）：位移标准差 / 平均位移 ≤ 该比例
    static let maxDisparity: CGFloat = 0.55
    /// 质心水平位移超过竖直位移的该比例时视为非下滑
    static let maxXRatio: CGFloat = 0.6
    /// 手动滚动后的隔离期：期间的三指接触视为"滚动+误触"，不触发
    static let scrollQuarantine: TimeInterval = 0.35

    /// 近期手动滚动有效期（时间戳之后的接触不算手势）
    private var userScrolledUntil: Date = .distantPast

    /// 滚动污染信号：手动滚动（phase != none）出现后的一段隔离期内，三指接触都视为
    /// "滚动 + 第三指误触"，不算手势触发。momentum（惯性尾，phase==none）不算手动滚动。
    func recordScroll(phase: NSEvent.Phase) {
        if phase != [] {
            userScrolledUntil = Date().addingTimeInterval(Self.scrollQuarantine)
        }
    }

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
                if startPositions.count == 3 { evaluateEnd() }
                reset()
            }
            return
        }

        let touching = next.values.filter { !$0.isEnded }
        let count = touching.count

        if startPositions.isEmpty {
            // 首次形成三指接触：记录每根手指起始 y 与质心 x
            if count == 3 {
                fingers = next
                for f in touching { startPositions[f.identity] = f.position.y }
                centroidXStart = centroid(touching).x
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

    /// 触发判定（三重防线）：
    /// ① 滚动污染检查：近期有手动滚动（两指滚动页面 + 第三指误触场景）→ 不触发
    /// ② 路径 A（严格三指）：三指全动 ≥0.08、方向一致、离散度 ≤0.55
    /// ③ 路径 B（二指主导，容纳"两动 + 一搭"姿势）：两根主拉手指 ≥0.15 且方向一致，
    ///    第三指 |dy| < 0.15 任意（静止亦可）
    private func evaluateEnd() {
        guard startPositions.count == 3 else { return }
        let snapshot = fingers.values.filter { startPositions[$0.identity] != nil }
        guard snapshot.count == 3 else { return }

        if Date() < userScrolledUntil {
            NSLog("[TrackpadX] 近期有手动滚动, 三指接触视为滚动+误触, 不触发")
            return
        }

        let deltas = snapshot.map { finger -> CGFloat in
            finger.position.y - (startPositions[finger.identity] ?? 0)
        }
        let meanDy = deltas.reduce(0, +) / 3
        let dx = abs(centroid(snapshot).x - centroidXStart)

        guard Date().timeIntervalSince(lastFired) > Self.cooldown else { return }
        guard abs(meanDy) >= Self.perFingerThresholdY, dx <= abs(meanDy) * Self.maxXRatio else {
            NSLog("[TrackpadX] 手势采样未达阈值 avgDy=%.4f dx=%.4f", Double(meanDy), Double(dx))
            return
        }

        var movedCount = 0
        var uniform = true
        for d in deltas {
            if abs(d) >= Self.perFingerThresholdY { movedCount += 1 }
            if d.sign != meanDy.sign { uniform = false }  // 静止或反向手指 → 严格路径失败
        }
        let variance = deltas.reduce(0) { $0 + ($1 - meanDy) * ($1 - meanDy) } / 3
        let disparity = sqrt(max(variance, 0)) / max(abs(meanDy), 0.001)

        // 路径 A：严格三指
        let strictOK = movedCount == 3 && uniform && disparity <= Self.maxDisparity
        // 路径 B：两根主拉手指（排除最近一根），第三根允许静止
        let sorted = deltas.sorted { abs($0) > abs($1) }
        let mainOK = abs(sorted[0]) >= Self.mainFingerThresholdY
            && abs(sorted[1]) >= Self.mainFingerThresholdY
            && sorted[0].sign == sorted[1].sign
            && sorted[1].sign == meanDy.sign
        let thirdQuiet = abs(sorted[2]) < Self.mainFingerThresholdY
        let twoLeadOK = mainOK && thirdQuiet

        NSLog("[TrackpadX] 逐指校验: deltas=%@ disparity=%.3f moved=%d strict=\(strictOK) twoLead=\(twoLeadOK)",
              deltas.map { String(format: "%.4f", Double($0)) }.joined(separator: ","))

        guard strictOK || twoLeadOK else {
            NSLog("[TrackpadX] 三指判定未通过（需整齐三指 或 两动+第三指搭放）")
            return
        }

        lastFired = Date()
        if meanDy < 0 {
            NSLog("[TrackpadX] 触发三指下滑 (avgDy=%.4f, \(strictOK ? "路径A整齐" : "路径B两动一搭"))", Double(meanDy))
            MinimizeWindowService.shared.performMinimize()
        } else {
            NSLog("[TrackpadX] 平均上滑 dy=%.4f，预留不触发", Double(meanDy))
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
        startPositions = [:]
        centroidXStart = 0
    }
}
