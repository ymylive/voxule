#!/usr/bin/env bash
# 屏幕巡检截图 —— 配合 ScreenTour（DEBUG 启动参数直达任意一屏）逐屏截图。
# 用法：
#   scripts/tour-shots.sh                     # 全部屏 · dark
#   scripts/tour-shots.sh --appearance light  # 全部屏 · light
#   scripts/tour-shots.sh shelf-grid detail   # 只巡这几屏
# 输出：design/tour-shots/<appearance>/<screen>.png
# 前置：scripts/run-sim.sh --build-only 已跑过（本脚本只装包+截图，不重新构建）。
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${DEVICE:-iPhone 17}"
APP_BUNDLE_ID="com.voxlue.voxule"
APP_PATH="/tmp/voxule-dd-sim/Build/Products/Debug-iphonesimulator/voxule.app"
APPEARANCE="dark"

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --appearance) APPEARANCE="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

# 全部巡检屏 —— 与 ScreenTour.Target 的 rawValue 保持一致。
ALL_SCREENS=(home shelf shelf-grid record framing detail surfaced map settings
             cadence health devtools circles circle-detail create-circle
             accept-invite about catalog onboarding)
SCREENS=("${ARGS[@]:-${ALL_SCREENS[@]}}")

OUT_DIR="design/tour-shots/$APPEARANCE"
mkdir -p "$OUT_DIR"

UDID=$(xcrun simctl list devices available \
       | grep -F "$DEVICE (" \
       | head -1 \
       | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[[ -n "$UDID" ]] || { echo "✗ no simulator named '$DEVICE'" >&2; exit 1; }

xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance "$APPEARANCE"
# 统一状态栏 —— 截图去掉时间/电量噪声。
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 2>/dev/null || true

xcrun simctl install "$UDID" "$APP_PATH"

for screen in "${SCREENS[@]}"; do
  xcrun simctl terminate "$UDID" "$APP_BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$APP_BUNDLE_ID" -uiTourScreen "$screen" >/dev/null
  sleep 2.5   # 首帧 + 字体注册 + 地图/列表异步加载
  xcrun simctl io "$UDID" screenshot "$OUT_DIR/$screen.png" >/dev/null
  echo "✓ $screen → $OUT_DIR/$screen.png"
done

xcrun simctl terminate "$UDID" "$APP_BUNDLE_ID" 2>/dev/null || true
echo "done: ${#SCREENS[@]} shots in $OUT_DIR"
