#!/bin/zsh
# TrackpadX 构建与打包脚本 (macOS 27 直发, 无签名)
# 依赖: swiftc (Command Line Tools), hdiutil (系统自带)
# 用法: ./build_app.sh            # 只产出 build/TrackpadX.app
#       ./build_app.sh --dmg      # 额外产出 dist/TrackpadX-x.y.z.dmg
set -euo pipefail
cd "$(dirname "$0")/../"

APP_NAME="TrackpadX"
BUNDLE_ID="com.resty.trackpadx"
VERSION=$(head -1 version.txt 2>/dev/null | tr -d '[:space:]'); [ -z "$VERSION" ] && VERSION="0.2.0"
BUILD_DIR="build"
STAGING="$BUILD_DIR/staging"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

# 1. 编译 (与冒烟命令一致)
mkdir -p "$BUILD_DIR"
# 顶层 main.swift 不兼容 -parse-as-library（入口模式：顶层代码手接 delegate）
swiftc \
  -import-objc-header Sources/ObjC/ExceptionCatcher.h \
  $(find Sources -name '*.swift' | sort) \
  Sources/ObjC/ExceptionCatcher.m \
  -o "$BUILD_DIR/$APP_NAME"

# 2. 组装 .app
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
mv "$BUILD_DIR/$APP_NAME" "$APP_PATH/Contents/MacOS/$APP_NAME"
if [[ -f Assets/AppIcon.icns ]]; then
  cp Assets/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
fi
cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>      <string>触摸板扩展</string>
    <key>CFBundleIdentifier</key>       <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>       <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleIconFile</key>         <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>  <true/>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>          <string>$VERSION</string>
    <key>LSUIElement</key>              <false/>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
</dict>
</plist>
EOF

echo "✅ App built: $APP_PATH"

# 3. --dmg: 产出 DMG
if [[ "${1:-}" == "--dmg" ]]; then
  mkdir -p "$STAGING" "dist"
  cp -R "$APP_PATH" "$STAGING/"
  cp -R "../docs" "$STAGING/参考文档" 2>/dev/null || true
  ln -s /Applications "$STAGING/Applications"   # 访达拖拽安装目标，不可缺
  cat > "$STAGING/安装到应用程序.command" <<'EOF'
#!/bin/zsh
# 拖拽不可用时：双击本文件即可安装（App Management TCC 拦截 Finder 时的兜底）
SRC="$(dirname "$0")/TrackpadX.app"
cp -R "$SRC" /Applications/ && open /Applications/TrackpadX.app
echo "已安装并启动 TrackpadX"
sleep 2
EOF
  chmod +x "$STAGING/安装到应用程序.command"
  DMG_OUT="dist/${APP_NAME}-${VERSION}.dmg"
  rm -f "$DMG_OUT"
  hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -fs HFS+ \
    -format UDZO \
    "$DMG_OUT" > /dev/null
  rm -rf "$STAGING"
  echo "✅ DMG built: $DMG_OUT (无签名，首次打开需 xattr -cr 或右键打开)"
fi
