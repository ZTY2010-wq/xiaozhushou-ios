#!/bin/bash
# ============================================================
#  小助手 iPhone 串流壳 —— 一键出版本 / 出 .ipa
#
#  用法：
#    ./build.sh unsigned          出未签名 .ipa（Sideloadly / AltStore / 爱思助手 自签安装）
#    ./build.sh signed <TEAM_ID>  出已签名 .ipa（需 Xcode 登录开发者账号）
#    ./build.sh run               直接编译装到已连接的 iPhone
#    ./build.sh clean             清理
#
#  前置：
#    xcode-select --install
#    brew install xcodegen
# ============================================================
set -euo pipefail

APP_NAME="XiaoZhuShou"
SCHEME="XiaoZhuShou"
PROJ="${APP_NAME}.xcodeproj"
BUILD_DIR="build"
OUT_DIR="out"

cd "$(dirname "$0")"

c_ok()   { printf "\033[32m✓\033[0m %s\n" "$*"; }
c_info() { printf "\033[36m·\033[0m %s\n" "$*"; }
c_err()  { printf "\033[31m✗\033[0m %s\n" "$*" >&2; }

need() {
  command -v "$1" >/dev/null 2>&1 || { c_err "缺少 $1 —— $2"; exit 1; }
}

precheck() {
  need xcodebuild "请先装 Xcode（App Store）并执行 xcode-select --install"
  if ! command -v xcodegen >/dev/null 2>&1; then
    c_info "未检测到 xcodegen，尝试安装…"
    if command -v brew >/dev/null 2>&1; then
      brew install xcodegen
    else
      c_err "没有 Homebrew。二选一：1) 装 brew（https://brew.sh）后 brew install xcodegen；2) 直接用 Xcode 打开本目录旁边附带的工程说明手动建工程。"
      exit 1
    fi
  fi
  c_info "生成 Xcode 工程…"
  xcodegen generate --spec project.yml
  c_ok "工程已生成：${PROJ}"
}

# ---------- 未签名 ipa（免开发者账号） ----------
build_unsigned() {
  precheck
  rm -rf "$BUILD_DIR" "$OUT_DIR"
  mkdir -p "$OUT_DIR"

  c_info "编译 arm64 Release（不签名）…"
  xcodebuild \
    -project "$PROJ" \
    -scheme "$SCHEME" \
    -configuration Release \
    -sdk iphoneos \
    -derivedDataPath "$BUILD_DIR" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

  APP_PATH="$BUILD_DIR/Build/Products/Release-iphoneos/${APP_NAME}.app"
  [ -d "$APP_PATH" ] || { c_err "编译产物缺失：$APP_PATH"; exit 1; }

  c_info "打包成 Payload 结构…"
  rm -rf "$OUT_DIR/Payload"
  mkdir -p "$OUT_DIR/Payload"
  cp -R "$APP_PATH" "$OUT_DIR/Payload/"

  IPA="$OUT_DIR/${APP_NAME}-1.0.0-unsigned.ipa"
  rm -f "$IPA"
  ( cd "$OUT_DIR" && zip -qry "$(basename "$IPA")" Payload )
  rm -rf "$OUT_DIR/Payload"

  c_ok "未签名 IPA 已生成：$(pwd)/$IPA"
  cat <<EOF

下一步（不花钱，用免费 Apple ID 自签安装）—— 三选一：

  ① Sideloadly（Windows/Mac 都能用，最省事）
     https://sideloadly.io  →  拖入 $(basename "$IPA")  →  填 Apple ID  →  Start
     装完去 iPhone「设置 → 通用 → VPN与设备管理」信任证书
     免费账号签名 7 天有效，到期重签即可

  ② AltStore / SideStore（自动续签，7 天一次）
     https://altstore.io   装好后把 IPA 拖进去

  ③ 爱思助手 / TrollStore（后者仅特定系统版本可用）

EOF
}

# ---------- 已签名 ipa ----------
build_signed() {
  local team="${1:-}"
  [ -n "$team" ] || { c_err "用法：./build.sh signed <TEAM_ID>（10 位团队 ID，Xcode 账号页可见）"; exit 1; }
  precheck
  rm -rf "$BUILD_DIR" "$OUT_DIR"
  mkdir -p "$OUT_DIR"

  c_info "Archive（team=$team）…"
  xcodebuild \
    -project "$PROJ" \
    -scheme "$SCHEME" \
    -configuration Release \
    -sdk iphoneos \
    -archivePath "$BUILD_DIR/${APP_NAME}.xcarchive" \
    -derivedDataPath "$BUILD_DIR" \
    DEVELOPMENT_TEAM="$team" \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates \
    archive

  cat > "$OUT_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>development</string>
    <key>teamID</key><string>${team}</string>
    <key>signingStyle</key><string>automatic</string>
    <key>stripSwiftSymbols</key><true/>
    <key>compileBitcode</key><false/>
    <key>destination</key><string>export</string>
</dict>
</plist>
PLIST

  c_info "导出 IPA…"
  xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/${APP_NAME}.xcarchive" \
    -exportPath "$OUT_DIR" \
    -exportOptionsPlist "$OUT_DIR/ExportOptions.plist" \
    -allowProvisioningUpdates

  c_ok "已签名 IPA：$(ls -1 "$OUT_DIR"/*.ipa 2>/dev/null || echo '（导出失败，检查设备 UDID 是否在描述文件中）')"
}

# ---------- 直接装机 ----------
run_device() {
  precheck
  local dev
  dev=$( { xcrun xctrace list devices 2>/dev/null || true; } \
         | { grep -iE 'iPhone|iPad' || true; } \
         | { head -1 || true; } \
         | { sed -E 's/.*\(([0-9A-Fa-f-]{25,})\).*/\1/' || true; } )
  [ -n "$dev" ] || { c_err "没检测到已连接的 iPhone（数据线连上并信任此电脑）"; exit 1; }
  c_info "目标设备 UDID：$dev"
  xcodebuild \
    -project "$PROJ" -scheme "$SCHEME" -configuration Debug \
    -sdk iphoneos -derivedDataPath "$BUILD_DIR" \
    -destination "id=$dev" \
    -allowProvisioningUpdates \
    build install
  c_ok "已安装到设备"
}

case "${1:-unsigned}" in
  unsigned) shift || true; build_unsigned ;;
  signed)   shift || true; build_signed "${1:-}" ;;
  run)      shift || true; run_device ;;
  clean)    rm -rf "$BUILD_DIR" "$OUT_DIR" "$PROJ"; c_ok "已清理" ;;
  *)        sed -n '2,18p' "$0" ; exit 1 ;;
esac
