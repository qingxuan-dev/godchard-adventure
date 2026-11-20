#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ -x "./gradlew" ]; then
  ./gradlew assembleRelease
elif command -v gradle >/dev/null 2>&1; then
  gradle assembleRelease
else
  echo "未检测到本地 gradle，请使用 Android Studio 打开本目录点击 Build -> Assemble Project，或上传至 GitHub 自动云端打包 APK！"
  exit 1
fi
echo "已生成签名正式版安装包：app/build/outputs/apk/release/GodchardAdventure-v2.0.0-release.apk"
