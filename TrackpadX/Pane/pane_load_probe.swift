import Foundation

// prefPane 加载诊断 harness: 独立进程内手动 load bundle, 输出真实错误
let path = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : NSHomeDirectory() + "/Library/PreferencePanes/TrackpadX.prefPane"

guard let bundle = Bundle(path: path) else {
    print("FAIL: Bundle(path:) 返回 nil — bundle 结构不合法")
    exit(1)
}
print("✅ bundle 结构合法:", bundle.bundleURL.lastPathComponent)
print("loaded flag:", bundle.isLoaded)
do {
    try bundle.loadAndReturnError()
    print("✅ loadAndReturnError 成功")
} catch {
    print("❌ loadAndReturnError 失败:", error)
}
print("principalClas lookup:", NSClassFromString("TrackpadXPane") as Any)
if let cls = NSClassFromString("TrackpadXPane") as? (NSObject.Type) {
    let obj = cls.init()
    print("✅ 类可见且实例化成功:", obj)
} else {
    print("❌ NSClassFromString(TrackpadXPane) 为 nil — 类未对 ObjC runtime 可见")
}
