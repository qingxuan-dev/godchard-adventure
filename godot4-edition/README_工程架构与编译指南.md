# 《哥查德的大冒险 · GODCHARD ADVENTURE》Godot 4.2.2 重制版 v4.0 完整工程

## 一、设计基准与冲突裁定说明
1. **系统与代码架构基准**：严格遵循《GODCHARD ADVENTURE 完整重制版总游戏设计文档（Master GDD v1.0）》与《98种对象类型注册表 v1.0》，实现 `TrapBase` / `TrapRegistry`（含原 98 种 + 27 种 v2.0 新增机关共 125 项契约）、`WorldState`、`PlayerController`、`BossStateMachine`、`LevelValidator`、`SaveManager`（原子双槽存档与四级奖章：`铜章` / `银章` / `金章` / `反套路徽章`）、`HintBlueprintView`（`轻提示` / `中提示` / `完整解法` 三级渐进提示，仅查看完整解法才禁用反套路徽章）与无障碍视觉音频字幕。
2. **150 关详细设计与优先级裁定**：第 `001`–`150` 关（共三大幕 15 章节）严格依据 **《GODCHARD ADVENTURE 150关高难度详细关卡设计 v2.0》** 全量实现；凡两份文档存在冲突之处（包括关卡名称、星级、高密度复合陷阱数、顺序敏感逻辑链、15 场大章机制型 Boss 及第 38/67/88/98 关中段守关 Boss、第 150 关五阶段“收剑背身静置等日落”终局），**100% 以 v2.0 详细 150 关文档为准**。
3. **美术与音效全量升级**：完整集成此前全目录逐张重绘透明化的高清像素精灵（含 22 帧哥查德主角动作组、30 枚关卡徽章、工业/赛博/幻境三幕地块与陷阱），并全新生成切片 30 张 v2.0 专属解谜机关精灵、12 张大型机制 Boss 精灵以及 14 种高辨识度解谜提示音效（合计 **423 项无损 `.import` 贴图资源、9 首 BGM、38 种音效**）。

## 二、目录结构
- `project.godot` / `export_presets.cfg`：Godot 4.2.2（`GL Compatibility`，`960x540` 像素对齐视口 + `1920x540` 超宽全景，Android 强制横屏 `sensorLandscape`）工程与四平台导出预设。
- `scenes/`：`Main.tscn` 主场景与 `DebugOverlay.tscn`（`F3` 实时碰撞框、`logic_graph` 连线、玩家状态与跳关诊断层）。
- `scripts/core/`：`event_bus.gd`、`grid_math.gd`、`world_state.gd`、`player_controller.gd`、`stage_engine.gd`、`trap_base.gd`、`trap_registry.gd`（125 项机关契约）、`level_validator.gd`、`save_manager.gd`。
- `scripts/sectors/` & `scripts/shop/`：`boss_state_machine.gd`、`sector_1_2_mechanics.gd`、`sector_3_arcadia.gd`、`shop_system.gd`。
- `scripts/ui/`、`scripts/audio/` & `scripts/game_main.gd`：`ui_director.gd`、`hint_blueprint_view.gd`、`title_bg_view.gd`、`debug_overlay.gd`、`chiptune_player.gd`。
- `data/`：`levels_150.json`（全 150 关合并主数据，含 4,730 个唯一 UUID 对象、639 条 `logic_graph` 因果边、294 个中途存档点、741 步有序解法）、`game_metadata.json`、中英文字体包。
- `assets/` & `audio/`：全套透明背景高清 PNG 资源（均配齐 `compress/mode=0` 无损 `.import`）与全部 `.ogg` / `.wav` 音频。

## 三、一键导入运行与全平台编译方式
### 方式 1：Godot 4.2.2 编辑器直接打开运行
1. 使用 **Godot 4.2.2-stable** 打开本目录下的 `project.godot`。
2. 按 `F5` 即可直接游玩；在 `项目 -> 导出 (Project -> Export)` 中可直接导出 `Android`、`Windows Desktop`、`Linux/X11` 或 `Web`。

### 方式 2：命令行一键自动化冒烟校验 + 全平台打包
在 Linux / WSL / macOS 终端或 GitHub Actions（已内置 `.github/workflows/build_godchard_v4.yml`）中直接运行：
```bash
bash ./ci_compile_godot4_v4.sh
```
脚本将自动拉取官方 Godot 4.2.2-stable 无头引擎与导出模板，执行 `-- --smoke-test`（逐关加载并驱动全部 150 关物理、Boss 与中途点自检），并在 `dist/` 目录输出已签名 Android `.apk`、Windows x64 `.zip` 与 Linux x86_64 `.zip`。
