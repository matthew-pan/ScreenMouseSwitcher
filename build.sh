#!/bin/bash
# 一键构建：编译通用二进制 -> 组装 .app -> 打包 .dmg（全部使用 macOS 原生工具链）
set -euo pipefail

# ---- 基本信息 ----
APP_NAME="ScreenMouseSwitcher"
DISPLAY_NAME="屏幕鼠标切换"
BUNDLE_ID="com.local.screenmouseswitcher"
VERSION="1.0"
BUILD_NUMBER="1"
MIN_MACOS="13.0"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# 最终产物目录（在项目内，可能位于 iCloud）。
OUT_DIR="$ROOT_DIR/build"
# 工作目录放在项目外的临时目录，避免 iCloud/Finder 自动附加 xattr 破坏代码签名。
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${APP_NAME}.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

APP_BUNDLE="$WORK_DIR/$APP_NAME.app"
DMG_STAGE="$WORK_DIR/dmg"
DMG_PATH="$WORK_DIR/$APP_NAME-$VERSION.dmg"

echo "==> 清理旧的构建产物"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# ---- 1. 编译通用二进制（arm64 + x86_64）----
# 用 swiftc 直接分架构编译再 lipo 合并，仅依赖 Command Line Tools（无需完整 Xcode）。
SOURCES=("$ROOT_DIR"/Sources/ScreenMouseSwitcher/*.swift)

echo "==> 编译 arm64"
swiftc -O -target "arm64-apple-macosx${MIN_MACOS}" "${SOURCES[@]}" -o "$WORK_DIR/$APP_NAME-arm64"

echo "==> 编译 x86_64"
swiftc -O -target "x86_64-apple-macosx${MIN_MACOS}" "${SOURCES[@]}" -o "$WORK_DIR/$APP_NAME-x86_64"

echo "==> 合并为通用二进制 (lipo)"
BIN_PATH="$WORK_DIR/$APP_NAME-universal"
lipo -create "$WORK_DIR/$APP_NAME-arm64" "$WORK_DIR/$APP_NAME-x86_64" -output "$BIN_PATH"
echo "    架构:  $(lipo -archs "$BIN_PATH")"

# ---- 2. 组装 .app 包 ----
echo "==> 组装 $APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# ---- 2a. 生成图标（失败则跳过，不影响构建）----
ICON_LINE=""
echo "==> 生成 App 图标"
if swift "$ROOT_DIR/scripts/make_icon.swift" "$WORK_DIR/icon_1024.png" 2>/dev/null; then
  ICONSET="$WORK_DIR/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 64 128 256 512; do
    sips -z $size $size "$WORK_DIR/icon_1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1 || true
    double=$((size * 2))
    sips -z $double $double "$WORK_DIR/icon_1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null 2>&1 || true
  done
  if iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null; then
    ICON_LINE="    <key>CFBundleIconFile</key><string>AppIcon</string>"
    echo "    图标已生成"
  else
    echo "    iconutil 失败，跳过图标"
  fi
else
  echo "    图标生成失败，跳过"
fi

# ---- 2b. 写 Info.plist ----
echo "==> 写 Info.plist"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
    <key>LSUIElement</key><true/>
$ICON_LINE
    <key>NSHumanReadableCopyright</key><string>© 2026</string>
</dict>
</plist>
PLIST

# ---- 3. 代码签名（可选，默认 ad-hoc；后续可换成 Developer ID）----
# 后续正式分发时，把下面一行替换为：
#   codesign --deep --force --options runtime --sign "Developer ID Application: 你的名字 (TEAMID)" "$APP_BUNDLE"
# 再用 notarytool 公证：
#   xcrun notarytool submit "$DMG_PATH" --apple-id <id> --team-id <TEAMID> --password <app-专用密码> --wait
#   xcrun stapler staple "$DMG_PATH"
echo "==> Ad-hoc 签名（不签名分发用，别人机器首次需右键打开）"
# 先清除扩展属性（iCloud/Finder 会附带 xattr，导致 codesign 失败）。
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
codesign --force --deep --sign - "$APP_BUNDLE"
echo "    已 ad-hoc 签名"

# ---- 4. 打包 DMG ----
echo "==> 打包 DMG"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

# 让 DMG 卷图标与 App 图标一致。
APP_ICNS="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
DMG_HAS_ICON=0
if [ -f "$APP_ICNS" ]; then
  cp "$APP_ICNS" "$DMG_STAGE/.VolumeIcon.icns"
  DMG_HAS_ICON=1
fi

rm -f "$DMG_PATH"
if [ "$DMG_HAS_ICON" = "1" ]; then
  # 先建可写 dmg，挂载后打上自定义图标位，再压缩为只读发行版。
  RW_DMG="$WORK_DIR/$APP_NAME-rw.dmg"
  rm -f "$RW_DMG"
  hdiutil create \
    -volname "$DISPLAY_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov -format UDRW \
    "$RW_DMG" >/dev/null
  MOUNT_DIR="$WORK_DIR/mnt"
  mkdir -p "$MOUNT_DIR"
  hdiutil attach "$RW_DMG" -noautoopen -mountpoint "$MOUNT_DIR" >/dev/null
  SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
  hdiutil detach "$MOUNT_DIR" >/dev/null || diskutil unmount "$MOUNT_DIR" >/dev/null 2>&1 || true
  hdiutil convert "$RW_DMG" -format UDZO -ov -o "$DMG_PATH" >/dev/null
  rm -f "$RW_DMG"
  echo "    DMG 卷图标已设置"
else
  hdiutil create \
    -volname "$DISPLAY_NAME" \
    -srcfolder "$DMG_STAGE" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null
fi

echo ""
echo "==> 校验签名"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" && echo "    签名校验通过"

# ---- 5. 拷回项目 build/ 目录 ----
echo "==> 输出到 $OUT_DIR"
cp -R "$APP_BUNDLE" "$OUT_DIR/"
cp "$DMG_PATH" "$OUT_DIR/"

echo ""
echo "==> 构建完成"
echo "    App:  $OUT_DIR/$APP_NAME.app"
echo "    DMG:  $OUT_DIR/$APP_NAME-$VERSION.dmg"
