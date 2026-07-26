#!/usr/bin/env bash
#
# 在 iPhone 17 模拟器上构建并启动 voxule。
#
# 用法：
#   scripts/run-sim.sh             # 增量构建 + 装 + 启
#   scripts/run-sim.sh --fresh     # 卸载 → 装 → 启（清 NSUserDefaults / SwiftData 库）
#   scripts/run-sim.sh --build-only
#   DEVICE="iPhone 17 Pro" scripts/run-sim.sh
#
# 为什么走脚本而不是直接 xcodebuild：
# 本机 SwiftPM 资源 bundle（VoxlueKit_VoxlueDesign.bundle 内 Fonts/Resources）
# 在 codesign 阶段会被拒为 "bundle format unrecognized"。模拟器不需要真签名，
# 把 CODE_SIGNING_ALLOWED=NO 限定在这里，不动 Xcode 工程配置 —— 真机 / TestFlight
# / CI 签名链路完全不受影响。

set -euo pipefail

DEVICE="${DEVICE:-iPhone 17}"
SCHEME="voxule"
BUNDLE_ID="com.voxlue.voxule"
DERIVED="/tmp/voxule-dd-sim"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)/voxule"

FRESH=0
BUILD_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --fresh)      FRESH=1 ;;
    --build-only) BUILD_ONLY=1 ;;
    -h|--help)
      sed -n '3,17p' "$0"
      exit 0 ;;
    *)
      echo "unknown arg: $arg" >&2
      exit 2 ;;
  esac
done

echo "→ xcodebuild ($DEVICE) ..."
xcodebuild \
  -project "$PROJECT_DIR/voxule.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | tail -5

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/voxule.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "✗ build did not produce $APP_PATH" >&2
  exit 1
fi
echo "✓ built: $APP_PATH"

if [[ $BUILD_ONLY -eq 1 ]]; then exit 0; fi

# 找到目标设备 UDID（包含 booted 或 shutdown 都行，先尝试启动）。
# 用 grep+sed 取 UDID —— macOS 默认 BSD awk 不支持 gawk 的 `match(str, re, arr)`
# 三参形式；用 POSIX 工具更便携。
UDID=$(xcrun simctl list devices available \
       | grep -F "$DEVICE (" \
       | head -1 \
       | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [[ -z "${UDID:-}" ]]; then
  echo "✗ no simulator named '$DEVICE'" >&2
  exit 1
fi
echo "→ device: $DEVICE ($UDID)"

# Boot 是幂等的 —— 已 boot 时返回非零但无害；显式忽略。
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

if [[ $FRESH -eq 1 ]]; then
  echo "→ fresh: uninstall first"
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
fi

echo "→ install + launch"
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" "$BUNDLE_ID"
echo "✓ running"
