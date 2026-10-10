# TrackpadX — Touchpad Extension / 触摸板扩展

[English](#english) | [中文](#中文)

<p>
<a href="https://github.com/restyhap/TrackpadX/releases/latest"><img alt="Release" src="https://img.shields.io/badge/release-v0.1.9-blue" /></a>
<img alt="Platform" src="https://img.shields.io/badge/macOS-13.0%2B-lightgrey" />
<img alt="License" src="https://img.shields.io/badge/license-MIT-green" />
</p>

---

<a id="中文"></a>
## 中文

macOS 触控板多功能扩展应用：**三指下滑最小化前台应用** + **输入时屏蔽触摸板**（防误触）。单一直发版，DMG 安装，无需 App Store。

### 功能

- **三指下滑**：触控板三指下滑 → 最小化当前前台应用的聚焦窗口（AX 最小化四级链：AX 动作 → 属性置位 → ⌘M 兜底 → 可选隐藏降级）。
- **输入时屏蔽触摸板**：打字后一小段时间内忽略触控板引起的鼠标位移与滚动，避免手掌误触；点击与拖拽不受影响（拖动窗口、文件等正常）；间隔 0.2–1.0 s 可调。
- **设置窗口**：仿系统设置——左列功能清单（通用 / 三指下滑 / 输入时屏蔽触摸板），右侧分支详情；权限状态、关于信息标注在「通用」首页。
- **关闭行为**：点击关闭按钮可选「直接退出」或「退出到后台运行」（后台运行时点击 Dock 图标可重新打开设置）。
- **开机自启**：通用页一键开启（SMAppService）。

### 下载安装

1. 从 [GitHub Releases](https://github.com/restyhap/TrackpadX/releases/latest) 下载 `TrackpadX-x.y.z.dmg`。
2. 挂载 DMG，把 **TrackpadX.app** 拖入 Applications。
3. 首次打开放行（无签名包，任选其一）：
   - 右键 **TrackpadX.app → 打开 → 再点“打开”**；
   - 或终端执行 `xattr -cr /Applications/TrackpadX.app`。

### 权限授权

| 功能 | 权限 |
|---|---|
| 三指下滑最小化 | 辅助功能（Accessibility）+ 输入监控（Input Monitoring） |
| 输入时屏蔽触摸板 | 辅助功能（Accessibility） |

打开应用后按「去授权…」按钮引导授权，授权后状态一秒内自动变为「权限已就绪」。

### 已知限制

- 若系统触控板设置中的 App Exposé 被设为「三指下滑」，三指下滑会同时触发系统的 App Exposé，建议改为四指下滑或关闭。
- 自定义手势无法替代系统手势：监听为 listen-only 公开 API，不拦截、不伪造事件（macOS 27 上的伪造路径已被系统封禁本应用也不使用）。

### 构建与打包

```zsh
cd TrackpadX
./Packaging/build_app.sh        # 产出 build/TrackpadX.app
./Packaging/build_app.sh --dmg  # 额外产出 dist/TrackpadX-x.y.z.dmg
```

### 卸载

1. 「通用」页关闭「登录时启用」，删除 `/Applications/TrackpadX.app`。
2. 可选清理：`defaults delete com.resty.trackpadx`。

---

<a id="english"></a>
## English

A multifunctional trackpad extension for macOS: **three-finger swipe down to minimize the frontmost app's focused window** + **suppress trackpad clicks and scrolling while typing** (palm-rejection). Distributed as a standalone DMG, no App Store required.

### Features

- **Three-finger swipe down**: minimizes the focused window of the frontmost application (a four-step AX chain: AX action → AXMinimized attribute → ⌘M fallback → optional hide degrade).
- **Suppress while typing**: discards trackpad clicks and scrolling for a short period after each keystroke; interval adjustable 0.2–1.0 s.
- **Settings window**: System-Settings-like layout — sidebar (General / Three-finger swipe / Suppress while typing) with detail pages on the right; permission status and About are shown on the General home page.
- **Close behavior**: closing the window can either quit the app or keep it running in background (reopen settings by clicking the Dock icon).
- **Launch at login**: one-click toggle on the General page (SMAppService).

### Installation

1. Download `TrackpadX-x.y.z.dmg` from [GitHub Releases](https://github.com/restyhap/TrackpadX/releases/latest).
2. Mount the DMG and drag **TrackpadX.app** into Applications.
3. Allow at first launch (unsigned build, either way works):
   - Right-click **TrackpadX.app → Open → Open**;
   - or run `xattr -cr /Applications/TrackpadX.app` in Terminal.

### Permissions

| Feature | Permissions |
|---|---|
| Three-finger swipe to minimize | Accessibility + Input Monitoring |
| Suppress while typing | Accessibility |

Click the on-page "Authorize…" button inside the app; the permission status refreshes automatically within a second after granting.

### Known limitations

- If App Exposé in System Settings > Trackpad is set to "Swipe down with three fingers", the system effect fires simultaneously; switching it to four fingers or off is recommended.
- Gestures are detected through listen-only public APIs — no event interception or simulation (the simulate path is blocked by macOS 27 and never used by this app).

### Build

```zsh
cd TrackpadX
./Packaging/build_app.sh        # produces build/TrackpadX.app
./Packaging/build_app.sh --dmg  # also produces dist/TrackpadX-x.y.z.dmg
```

### Uninstall

1. Turn off "Launch at login" on the General page, then delete `/Applications/TrackpadX.app`.
2. Optional: `defaults delete com.resty.trackpadx`.

---

## License / 许可

Released under the [MIT License](LICENSE). / 基于 MIT 许可证开源。
