# TrackpadX 项目工作规范（desktop-03-gesture）

> 本文件对 TrackpadX（触摸板扩展）工程生效，与全局 AGENTS.md 叠加。

## 版本号迭代规则（强制，2026-10-10 用户定案）

背景：DMG 版本号曾出现 version.txt 改了但打包脚本仍发旧版、以及升版滞后于代码改动的情况。

规则：

1. **有代码/文档/打包脚本改动 → 必须同步升版**，不允许"改了东西不带版本号"。
2. **用户未明确指定新版本号时 → 按默认自动迭代 `0.1.n`**（即 patch 位 +1，如 0.1.3 → 0.1.4）。
3. **`0.1.9` 之后的下一版 = `0.2.0`**（patch 位封顶 9，进位到 minor）。`0.2.9` 之后同理进 `0.3.0`。
4. 版本唯一入口：`TrackpadX/version.txt`（单行纯号，如 `0.1.3`），`Packaging/build_app.sh` 用 `head -1 version.txt` 解析；DMG 文件名、Info.plist 的 `CFBundleShortVersionString`/`CFBundleVersion` 均由其派生，通用设置页显示读 Bundle，全链一致性由脚本保证。
5. 升版后必须重出 DMG 并用 `plutil -extract CFBundleShortVersionString raw build/TrackpadX.app/Contents/Info.plist` 校验一致，再删旧 DMG 防混。

## 构建要点（快速索引）

- swiftc 构建（无 xcodegen，见 `Packaging/build_app.sh`）；`--dmg` 产 `dist/TrackpadX-<Ver>.dmg`。
- `main.swift` 顶层入口手接 delegate（勿用 `@main` + NSApplicationMain 组合）。
- detail 页约束激活必须在 `addArrangedSubview` 之后（AppKit 会吞 delegate 回调里的 ObjC 异常 → 无窗口不崩溃）。
