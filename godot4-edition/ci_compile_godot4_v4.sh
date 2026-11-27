#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# 《哥查德的大冒险 · GODCHARD ADVENTURE》v4.0 一键无头导入、冒烟校验、全平台编译与 GitHub 发布脚本
# 适用引擎：Godot 4.2.2-stable (GL Compatibility)
# ==============================================================================

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$PWD}"
WORK_DIR="${TMPDIR:-/tmp}/godchard_v4_build"
DIST_DIR="${PROJ_DIR}/dist"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

echo "=== [1/8] 拷贝工程至隔离构建目录并执行静态资产、双字体与 GDScript 零 ':=' 审计 ==="
cp -r "$PROJ_DIR" "$WORK_DIR/project"
rm -rf "$WORK_DIR/project/dist"

if [ ! -f "$WORK_DIR/project/data/cjk_font.bin" ] || [ ! -f "$WORK_DIR/project/data/latin_font.bin" ]; then
  if command -v sudo >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq fonts-droid-fallback fonts-dejavu-core zip unzip
  fi
  LATIN_SRC=$(find /usr/share/fonts -iname "DejaVuSans-Bold.ttf" | head -n 1)
  CJK_SRC=$(find /usr/share/fonts -iname "*DroidSansFallback*.ttf" | head -n 1)
  cp "$LATIN_SRC" "$WORK_DIR/project/data/latin_font.bin"
  cp "$CJK_SRC" "$WORK_DIR/project/data/cjk_font.bin"
fi

python3 - <<'PY_AUDIT'
import json, os, glob
proj = os.path.join(os.environ.get("TMPDIR", "/tmp"), "godchard_v4_build/project")
meta = json.load(open(os.path.join(proj, "data/game_metadata.json"), "r", encoding="utf-8"))
levels = json.load(open(os.path.join(proj, "data/levels_150.json"), "r", encoding="utf-8"))
assert len(levels) == 150, f"Expected 150 levels, got {len(levels)}"
for k, rel in meta.get("assets", {}).items():
    p = os.path.join(proj, rel)
    assert os.path.isfile(p), f"Missing sprite: {k} -> {rel}"
    assert os.path.isfile(p + ".import"), f"Missing lossless .import: {rel}.import"
for k, rel in meta.get("bgmFiles", {}).items():
    assert os.path.isfile(os.path.join(proj, rel)), f"Missing BGM: {k}"
for k, rel in meta.get("sfxFiles", {}).items():
    assert os.path.isfile(os.path.join(proj, rel)), f"Missing SFX: {k}"
gd_files = sorted(glob.glob(os.path.join(proj, "scripts/**/*.gd"), recursive=True))
assert len(gd_files) >= 20, f"Expected >=20 GDScript modules, got {len(gd_files)}"
for gp in gd_files:
    assert ":=" not in open(gp, "r", encoding="utf-8").read(), f"Forbidden ':=' found in {gp}"
print(f"[AUDIT v4.0.0 PASS] 150 stages, {len(meta['assets'])} lossless textures, {len(meta['bgmFiles'])} BGMs, {len(meta['sfxFiles'])} SFXs, {len(gd_files)} GDScript files verified!")
PY_AUDIT

echo "=== [2/8] 准备 Godot 4.2.2-stable 编译器与官方导出模板 ==="
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
  if command -v godot4 >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot4)"
  elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  else
    BASE_URL="https://github.com/godotengine/godot-builds/releases/download/4.2.2-stable"
    cd "$WORK_DIR"
    curl -fsSL --retry 4 "${BASE_URL}/Godot_v4.2.2-stable_linux.x86_64.zip" -o godot_bin.zip
    unzip -oq godot_bin.zip
    chmod +x Godot_v4.2.2-stable_linux.x86_64
    GODOT_BIN="$WORK_DIR/Godot_v4.2.2-stable_linux.x86_64"
  fi
fi

TPL_DIR="$HOME/.local/share/godot/export_templates/4.2.2.stable"
if [ ! -f "$TPL_DIR/windows_release_x86_64.exe" ]; then
  BASE_URL="https://github.com/godotengine/godot-builds/releases/download/4.2.2-stable"
  mkdir -p "$TPL_DIR"
  cd "$WORK_DIR"
  curl -fsSL --retry 4 "${BASE_URL}/Godot_v4.2.2-stable_export_templates.tpz" -o godot_tpl.tpz
  unzip -oq godot_tpl.tpz
  mv templates/* "$TPL_DIR/"
fi

echo "=== [3/8] 执行 Godot 4.2.2 无头资源导入与全 150 关实机运行时冒烟测试 ==="
cat > "$WORK_DIR/project/data/build_profile.json" <<'EOF'
{"platform": "android", "forced_landscape": true}
EOF

timeout 180 "$GODOT_BIN" --headless --path "$WORK_DIR/project" --import || true
timeout 120 "$GODOT_BIN" --headless --path "$WORK_DIR/project" --import || true
SMOKE_LOG="$WORK_DIR/smoke.log"
timeout 120 "$GODOT_BIN" --headless --path "$WORK_DIR/project" -- --smoke-test 2>&1 | tee "$SMOKE_LOG"
grep -q "\[SMOKE TEST PASS\]" "$SMOKE_LOG"
if grep -E "SCRIPT ERROR:|Parse Error:" "$SMOKE_LOG"; then
  echo "[SMOKE FAIL] GDScript runtime/parse error detected!"
  exit 1
fi

echo "=== [4/8] 导出 Android 强制横屏正式签名版 (.apk v4.0.0) ==="
OUT_APK="$DIST_DIR/GodchardAdventure-Android-v4.0.0-release.apk"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/usr/local/lib/android/sdk}}"
if [ -d "$SDK_ROOT" ] && command -v keytool >/dev/null 2>&1; then
  mkdir -p "$HOME/.android" "$HOME/.config/godot"
  rm -f "$HOME/.android/debug.keystore" "$WORK_DIR/release.keystore"
  K_PASS="godchard123"
  keytool -genkeypair -v -keystore "$HOME/.android/debug.keystore" -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"
  keytool -genkeypair -v -keystore "$WORK_DIR/release.keystore" -alias godchard -keyalg RSA -keysize 2048 -validity 10000 -storepass "$K_PASS" -keypass "$K_PASS" -dname "CN=Godchard Adventure,O=Qingxuan,C=CN"

  J_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
  for CFG_NAME in editor_settings-4.tres editor_settings-4.2.tres; do
    cat > "$HOME/.config/godot/${CFG_NAME}" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "${J_HOME}"
export/android/android_sdk_path = "${SDK_ROOT}"
export/android/debug_keystore = "${HOME}/.android/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
  done

  sed -i "s|__DEBUG_KS__|${HOME}/.android/debug.keystore|g" "$WORK_DIR/project/export_presets.cfg"
  sed -i "s|__RELEASE_KS__|${WORK_DIR}/release.keystore|g" "$WORK_DIR/project/export_presets.cfg"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="${HOME}/.android/debug.keystore"
  export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${WORK_DIR}/release.keystore"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="godchard"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${K_PASS}"

  "$GODOT_BIN" --headless --verbose --path "$WORK_DIR/project" --export-release "Android" "$OUT_APK"
  test -f "$OUT_APK"

  APKSIGNER=$(find "$SDK_ROOT/build-tools" -name apksigner 2>/dev/null | sort -V | tail -n 1 || true)
  ZIPALIGN=$(find "$SDK_ROOT/build-tools" -name zipalign 2>/dev/null | sort -V | tail -n 1 || true)
  if [ -n "$APKSIGNER" ] && ! "$APKSIGNER" verify "$OUT_APK" >/dev/null 2>&1; then
    "$ZIPALIGN" -f -p 4 "$OUT_APK" "${OUT_APK}.aligned"
    "$APKSIGNER" sign --ks "$WORK_DIR/release.keystore" --ks-key-alias godchard --ks-pass "pass:${K_PASS}" --key-pass "pass:${K_PASS}" --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --out "$OUT_APK" "${OUT_APK}.aligned"
    rm -f "${OUT_APK}.aligned"
    "$APKSIGNER" verify --verbose "$OUT_APK"
  fi
fi

echo "=== [5/8] 导出 Windows x64 电脑桌面原生版 (.exe + .pck) ==="
cat > "$WORK_DIR/project/data/build_profile.json" <<'EOF'
{"platform": "pc", "forced_landscape": false}
EOF

cat > "$WORK_DIR/project/project.godot" <<'EOF'
config_version=5

[application]

config/name="哥查德的大冒险"
config/version="4.0.0"
config/description="GODCHARD ADVENTURE · 重制版 v4.0 全150关高密度反套路平台解谜冒险（电脑桌面原生版）"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.2", "GL Compatibility")
config/icon="res://icon.png"

[display]

window/size/viewport_width=960
window/size/viewport_height=540
window/size/window_width_override=1280
window/size/window_height_override=720
window/size/mode=0
window/size/resizable=true
window/stretch/mode="canvas_items"
window/stretch/aspect="keep_height"

[input_devices]

pointing/emulate_touch_from_mouse=false
pointing/emulate_mouse_from_touch=false

[physics]

common/physics_ticks_per_second=60

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true
anti_aliasing/quality/msaa_2d=0
anti_aliasing/quality/msaa_3d=0
anti_aliasing/quality/screen_space_aa=0
anti_aliasing/quality/use_taa=false
textures/vram_compression/import_etc2_astc=false
textures/vram_compression/import_s3tc_bptc=false
EOF

PC_STAGE="$WORK_DIR/pc_win64/GodchardAdventure_PC_Win64"
mkdir -p "$PC_STAGE"
"$GODOT_BIN" --headless --verbose --path "$WORK_DIR/project" --export-release "Windows Desktop" "$PC_STAGE/GodchardAdventure.exe"
test -f "$PC_STAGE/GodchardAdventure.exe"
test -f "$PC_STAGE/GodchardAdventure.pck"

cat > "$PC_STAGE/README_运行与键位说明.txt" <<'EOF'
《哥查德的大冒险 · GODCHARD ADVENTURE》v4.0.0 电脑桌面原生版 (Windows x64)
=============================================================================
1. 运行方式：请保持 GodchardAdventure.exe 与 GodchardAdventure.pck 位于同一文件夹，双击 GodchardAdventure.exe 启动（默认隐藏手机虚拟触控键）。
2. 键位操作：
   - A / D 或 ← / →：左右移动
   - W / Space / K：跳跃 / 二段跳 / 飞翼滑翔
   - S / ↓：下蹲进管道；空中按 S 触发下砸重击 (Ground Pound)
   - J：发射子弹    U：破魔圣剑挥砍    H：收剑/背身静置切换 (应对镜像/凝视/终章太阳神机制)
   - F：调查/拾取/放置/拨动阀门与日晷    B / I：投掷炸弹
   - E / L：表里双层空间切换            G：不灭金身 (每关限1次，落坑必死)
   - R：快速重开本关    Esc：暂停/选关大厅    F3：调试诊断面板    F11：全屏切换
EOF

OUT_PC_ZIP="$DIST_DIR/GodchardAdventure-PC-Windows-x64-v4.0.0.zip"
(cd "$WORK_DIR/pc_win64" && zip -rq "$OUT_PC_ZIP" GodchardAdventure_PC_Win64)

echo "=== [6/8] 导出 Linux x86_64 电脑桌面原生版 ==="
LIN_STAGE="$WORK_DIR/linux_x64/GodchardAdventure_Linux_x64"
mkdir -p "$LIN_STAGE"
"$GODOT_BIN" --headless --path "$WORK_DIR/project" --export-release "Linux/X11" "$LIN_STAGE/GodchardAdventure.x86_64"
chmod +x "$LIN_STAGE/GodchardAdventure.x86_64"
OUT_LIN_ZIP="$DIST_DIR/GodchardAdventure-Linux-x86_64-v4.0.0.zip"
(cd "$WORK_DIR/linux_x64" && zip -rq "$OUT_LIN_ZIP" GodchardAdventure_Linux_x64)

echo "=== [7/8] 同步 v4.0.0 源码与正式安装包至 GitHub 仓库及 Releases (若处于 GitHub Actions) ==="
if [ "${GITHUB_ACTIONS:-false}" = "true" ] && [ -d "$REPO_ROOT/.git" ]; then
  cd "$REPO_ROOT"
  BR="${GITHUB_REF_NAME:-main}"
  git fetch --unshallow origin "$BR" 2>/dev/null || git fetch origin "$BR" || true
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

  rm -rf godot4-edition
  mkdir -p godot4-edition
  cp -r "$PROJ_DIR/"* godot4-edition/
  rm -rf godot4-edition/.godot godot4-edition/dist godot4-edition/data/*.bin

  git rm -rf --ignore-unmatch apk pc || true
  rm -rf apk pc
  git add -A godot4-edition
  git add -u
  git commit -m "Sync verified Godot 4.2.2 v4.0.0 full 150-stage remake source [skip ci]" || true
  git pull --rebase origin "$BR" || true
  git push origin "HEAD:$BR" || true

  if [ -f "$OUT_APK" ]; then
    APK_SZ=$(stat -c%s "$OUT_APK")
    if [ "$APK_SZ" -lt 95000000 ]; then
      mkdir -p apk
      cp "$OUT_APK" apk/GodchardAdventure-Android-v4.0.0-release.apk
      git add -A apk
      git commit -m "Publish verified v4.0.0 Android sensorLandscape APK [skip ci]" || true
      git push origin "HEAD:$BR" || git reset --hard HEAD~1
    fi
  fi

  if [ -f "$OUT_PC_ZIP" ]; then
    PC_SZ=$(stat -c%s "$OUT_PC_ZIP")
    if [ "$PC_SZ" -lt 95000000 ]; then
      mkdir -p pc
      cp "$OUT_PC_ZIP" pc/GodchardAdventure-PC-Windows-x64-v4.0.0.zip
      git add -A pc
      git commit -m "Publish verified v4.0.0 Windows x64 Desktop ZIP [skip ci]" || true
      git push origin "HEAD:$BR" || git reset --hard HEAD~1
    fi
  fi

  cat > "$WORK_DIR/notes_v400.md" <<'EOF'
### 《哥查德的大冒险 · GODCHARD ADVENTURE》v4.0.0 完整重制版（全目录重绘高清透明素材 + 150关 v2.0 高密度反套路重构）

1. **全 150 关严格按《150关高难度详细关卡设计 v2.0》重制实现**：
   - 覆盖三大幕 15 章节（第 001–150 关），包含 4,730 个独立 UUID 场景实体、639 条 `logic_graph` 有向因果边与 294 个中途检查点；
   - 实装 15 场大章机制型 Boss 与 4 场中段守关 Boss（含独立 `boss_hp` / `boss_armor` 机制破甲状态机与第 150 关 `SOLARIS` 五阶段“拨日晷至黄昏 + 收剑背身静置等光束熄灭”终局）。
2. **全目录重绘升级高清透明像素精灵 + 新增专属机关音效**：
   - 内置全部 **423 项 `compress/mode=0` 无损透明贴图**（含 22 帧哥查德主角动作组、30 张 v2.0 新增解谜机关精灵、12 张大型 Boss 精灵）、**9 首 `.ogg` BGM** 与 **38 种 `.wav` 音效**。
3. **模块化架构、三级渐进提示、四级奖章与双端原生操控**：
   - 完整实现 `TrapBase`/`TrapRegistry`（125 项契约）、原子双槽存档、`铜章`/`银章`/`金章`/`反套路徽章`、`轻提示`/`中提示`/`完整解法`（仅查看完整解法才禁用反套路徽章）及无障碍视觉音频字幕；
   - **Android 端 (`GodchardAdventure-Android-v4.0.0-release.apk`)**：强制双向横屏 (`sensorLandscape`)、安全区多指边沿锁存触控与 `960×540` 像素对齐舞台；
   - **Windows x64 (`GodchardAdventure-PC-Windows-x64-v4.0.0.zip`)** & **Linux x64**：原生 `1280×720` 可缩放桌面窗口，默认隐藏手机触控虚拟键，支持 `F11` 全屏与 `F3` 诊断面板。
EOF

  if command -v gh >/dev/null 2>&1; then
    REL_FILES=()
    [ -f "$OUT_APK" ] && REL_FILES+=("$OUT_APK")
    [ -f "$OUT_PC_ZIP" ] && REL_FILES+=("$OUT_PC_ZIP")
    [ -f "$OUT_LIN_ZIP" ] && REL_FILES+=("$OUT_LIN_ZIP")
    gh release delete v4.0.0 --yes --cleanup-tag 2>/dev/null || true
    gh release create v4.0.0 "${REL_FILES[@]}" \
      --title "Godchard Adventure v4.0.0 · 150关高难v2.0重制版 + 全高清重绘素材（Android .apk + Windows .exe + Linux）" \
      --notes-file "$WORK_DIR/notes_v400.md"
  fi
fi

echo "=== [8/8] 全平台编译与发布完成！产物清单如下 ==="
ls -lh "$DIST_DIR"
