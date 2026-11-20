# 《哥查德的大冒险 · GODCHARD ADVENTURE》安卓原生工程包 (Android Edition v2.0)

本工程为针对 Android 7.0 – Android 15 (SDK 24–34) 深度定制的原生全屏横屏工程（包名 `com.godchard.adventure`），已内置升级版全 50 关游戏资源、多分辨率自适应像素图标与**预生成的正式版签名密钥库 (`app/godchard-release-key.jks`)**。

## 安卓原生专属特性
1. **真横屏沉浸无黑边**：默认锁定 `sensorLandscape` 双向重力感应横屏，开启挖孔屏/刘海屏 `shortEdges` 延伸显示与隐藏系统状态栏/导航栏。
2. **原生线性马达震动 (`GotchardAndroid.vibrateOneShot` / `vibratePattern`)**：跳跃、受击、护盾格挡、镜面折射、炸弹破墙均联动 Android 原生 `VibrationEffect` 波形震动（可在游戏设置中随时开关）。
3. **双保险本地持久化存档 (`SharedPreferences` + `localStorage`)**：通关星级、250 智商记录、按键大小缩放与已解锁 CG 实时同步写入安卓原生 `SharedPreferences`，即使清理系统缓存也不会丢失进度。
4. **原生返回手势与前后台音频管理**：左滑/右滑系统返回手势自动关闭当前弹窗或在局内呼出暂停菜单（不会误退游戏）；锁屏或切后台时自动挂起 8-Bit 芯片音乐并保存进度，回到前台无缝恢复。

## 两种超简生成 `.apk` 安装包方式

### 方式一：零环境配置 · GitHub Actions 云端一键生成签名 APK（推荐，无需安装 Android Studio）
1. 在 GitHub 新建仓库，将解压后的全部文件（含隐藏目录 `.github/workflows/build-android-apk.yml`）上传推送到 `main` 分支。
2. 打开仓库顶部的 **Actions** 页面，等待约 1.5–2 分钟构建完成。
3. 在构建详情页底部 **Artifacts** 直接下载已签名的正式版安装包 **`GodchardAdventure-Release-APK`**（内含 `GodchardAdventure-v2.0.0-release.apk`，发到手机即可直接安装）。

### 方式二：本地 Android Studio 或命令行一键打包
- **Android Studio**：选择 `Open` 打开解压后的 `GODCHARD_ADVENTURE_Android` 文件夹，待 Gradle 同步完成后点击菜单 `Build -> Generate Signed App Bundle or APK` 或直接运行 `./build_apk.sh`（Windows 双击 `build_apk.bat`）。
- 生成的正式签名安装包位于：`app/build/outputs/apk/release/GodchardAdventure-v2.0.0-release.apk`。
