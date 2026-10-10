import Cocoa
import QuartzCore

// 入口：顶层代码手接 delegate（对齐 TouchpadBlocker 已验证模式；swiftc 顶层代码必须放 main.swift）
NSLog("[TrackpadX] main: entering")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
NSLog("[TrackpadX] main: delegate wired")
app.setActivationPolicy(Store.dockVisible ? .regular : .accessory)
app.run()
