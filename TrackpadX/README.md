# TrackpadX — 触摸板扩展

macOS 触控板多功能扩展：**三指下滑最小化前台应用** + **输入时屏蔽触摸板**（防误触），单一直发版，DMG 安装。

- 目标系统：macOS 13.0+（实机验证于 macOS 27 Golden Gate 27.0.1）
- bundle ID：`com.resty.trackpadx`
- 交付：无签名 DMG（`dist/TrackpadX-<version>.dmg`）

---

## 安装

1. 双击挂载 `TrackpadX-x.y.z.dmg`，把 **TrackpadX.app** 拖入 Applications（或任意位置）。
2. **首次打开放行（无签名包）**，任选其一：
   - 右键 **TrackpadX.app → 打开 → 再点"打开"**；
   - 或终端执行 `xattr -cr /Applications/TrackpadX.app`（清除隔离属性）。
3. 打开后进入设置窗口。

## 权限授权（两个，按需弹引导）

| 功能 | 权限 | 深链 |
|---|---|---|
| 三指下滑最小化 | 辅助功能 (Accessibility) + 输入监控 (Input Monitoring/ListenEvent) | 「三指下滑」页 → 去授权… |
| 输入时屏蔽触摸板 | 辅助功能 (Accessibility) | 「输入时屏蔽触摸板」页 → 打开辅助功能设置… |

授权后在设置页状态应变为「权限已就绪」。缺权限时对应行显示橙色提示。

## 设置入口

主窗口「触摸板扩展」：左列功能清单 + 右侧分支详情（仿系统设置）。

- **三指下滑**：开关；"全屏聚焦窗口无法最小化时"子选项（不动作 / 隐藏前台应用）；⚠️ 若系统设置的 App Exposé 为三指下滑会发生并发动作，请到 触控板 设置改为四指或关闭（页面内有深链按钮）。
- **输入时屏蔽触摸板**：开关；屏蔽间隔（0.2/0.3/0.5/0.7/1.0 s）。
- **通用**：登录时启用（SMAppService）；应用信息。

## 已知限制（macOS 27 实验记录）

- 第三方 prefPane 进系统设置侧栏在 macOS 27 被签名校验拒绝（实验文档见 `docs/03-方案设计.md` §9），设置入口因此为应用内窗口。
- `dy` 方向由触摸板归一化坐标决定，若首次实机三指下滑反向上滑生效，属方向取反，日志可见。

## 构建与打包

```zsh
./Packaging/build_app.sh        # 产出 build/TrackpadX.app
./Packaging/build_app.sh --dmg  # 额外产出 dist/TrackpadX-x.y.z.dmg
```

技术栈：swiftc 直编（Command Line Tools，未用 xcodebuild，因本机 xcode-select 指 CLT）；ObjC 垫片 `txCatchObjCException` 防护 `NSTouch.normalizedPosition` 间接触摸异常。

## 卸载

1. 通用页关闭"登录时启用"；删除 `/Applications/TrackpadX.app`。
2. 可选清理：`defaults delete com.resty.trackpadx`。
