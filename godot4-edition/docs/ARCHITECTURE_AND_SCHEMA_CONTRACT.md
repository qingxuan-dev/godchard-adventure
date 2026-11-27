# 《哥查德的大冒险》Godot 4.2.2 重制版 v4.0 架构与 150 关数据契约规范

> **冲突解决最高准则**：
> 1. 工程整体架构、模块化组件 (`TrapBase`/`TrapRegistry`)、手感参数、触控与键鼠 UI、三级提示、双槽原子存档、四级奖章与无障碍视觉字幕遵循《GODCHARD_ADVENTURE_Master_GDD_v1.0.md》。
> 2. 全部 15 章（001–150 关）的关卡名称、星级、坑型分类（C/I/P/S/T/A/M）、反套路机制密度（普通关 ≥3 个事件、组合关 4–6 个、终关/Boss 5–8 个阶段）、地图结构、真实通关步骤（①②③④⑤）、诱饵与复盘线索、15 场机制型非血牛 Boss 战，**严格以 `/working_dir/c_1aafe114086ced29/user_uploaded_files/ttl=63d/user_uploaded/GODCHARD_ADVENTURE_150关高难度详细关卡设计_v2.0 (1).md` 为准**！凡与 v1.0 温和设计冲突处，100% 服从 v2.0！

---

## 一、工程目录结构 (`/working_dir/c_1aafe114086ced29/work/Godchard_v4_Project`)

```text
Godchard_v4_Project/
├── project.godot
├── export_presets.cfg
├── icon.png
├── assets/                     # 已内置全部重绘高清透明 PNG + 新增 30 张 v2.0 机关与 15 Boss 贴图
├── audio/                      # 9 首章节/Boss BGM (.ogg) + 38 种高辨识度音效 (.wav)
├── data/
│   ├── game_metadata.json      # 贴图/音频/成就/商店/15章元数据/多语言与视觉字幕配置
│   ├── levels_act1_001_050.json # 子智能体 1 产出：第 1–50 关 v2.0 完整数据
│   ├── levels_act2_051_100.json # 子智能体 2 产出：第 51–100 关 v2.0 完整数据
│   ├── levels_act3_101_150.json # 子智能体 3 产出：第 101–150 关 v2.0 完整数据
│   └── levels_150.json         # 合并校验后的 001–150 全量关卡主数据
├── scenes/
│   └── Main.tscn               # 主场景入口
└── scripts/                    # 子智能体 4 产出：模块化 GDScript 4.2 代码（严禁 Variant `:=` 推导！）
    ├── game_main.gd            # GameRoot 顶层协调、渲染管线、视差背景、--smoke-test 自动化验收器
    ├── core/
    │   ├── event_bus.gd        # EventBus 全局事件与视觉字幕广播
    │   ├── grid_math.gd        # 48px/格 世界坐标与碰撞几何工具
    │   ├── world_state.gd      # WorldState（重力轴、时间分区、前景/背景层、风惯性、水压、日晷相位、热量/影长、权限 READ/WRITE/ADMIN）
    │   ├── player_controller.gd# 角色物理（Coyote 130ms、Buffer 150ms、可变跳切速、二段惯性反转、三段下砸、能量弹/强化反射弹、破魔剑弹反、主动收剑 Sheathe、拾取/放置/投掷、飞翼折叠/影长续航、切层预览）
    │   ├── trap_base.gd        # class_name TrapBase extends Node2D 标准状态机接口 (IDLE/ARMED/WARNING/ACTIVE/COOLDOWN/RESET)
    │   ├── trap_registry.gd    # 98种原版对象 + v2.0 扩展对象的注册表与组件元数据契约
    │   ├── level_validator.gd  # 构建期与加载期 Schema、UUID、引用完整性、出口可达与防软锁校验器
    │   ├── stage_engine.gd     # 关卡主循环、信号/逻辑图驱动、检查点状态快照与回放残影
    │   └── save_manager.gd     # 双槽原子存档 + 损坏回滚 + 四级奖章（铜章/银章/金章/反套路徽章）
    ├── sectors/
    │   ├── sector_1_2_mechanics.gd # 经典篇与根源系统篇机关、敌人仇恨链、宝箱怪吞吐、404弹窗、权限补丁
    │   ├── sector_3_arcadia.gd     # 晴空篇四态云、五管水压阀、忍狸木桩、日晷、磁极渡轮、白鸽、鼹鼠扳手
    │   └── boss_state_machine.gd   # 全 15 关守关 Boss 独立多阶段解谜状态机（010/020/030/040/050/060/070/080/090/100/110/120/130/140/150）
    ├── shop/
    │   └── shop_system.gd      # 商店交易、退货槽回收、地图透镜与可选辅助道具
    ├── audio/
    │   └── chiptune_player.gd  # BGM 切换、音效播放与无障碍视觉音频字幕同步触发
    └── ui/
        ├── hint_blueprint_view.gd  # 三级渐进提示（轻提示/中提示/完整路线）与战术蓝图
        ├── title_bg_view.gd        # 动态标题主视觉与超宽屏视差夜景
        └── ui_director.gd          # 主菜单、15章卡片、10关选关、HUD（状态/权限/收剑/Boss护甲与HP分离）、结算奖章、设置与无障碍面板
```

---

## 二、150 关 v2.0 统一关卡 JSON Schema（所有关卡构建子智能体必须严格遵守）

每个关卡文件（`levels_act1_001_050.json`、`levels_act2_051_100.json`、`levels_act3_101_150.json`）顶层为包含 50 个关卡字典的 JSON 数组 `[ {...}, ... ]`，单关结构必须同时兼容引擎运行时字段与 Master GDD 14.3 规范字段：

```json
{
  "id": 1,
  "level_id": "001",
  "chapter": 1,
  "chapter_id": "ch01",
  "chapterName": "本能误导课",
  "name": "欢迎向右的你",
  "nameEn": "Welcome Going Right",
  "lineageName": "欢迎来到对面",
  "stars": 2,
  "pitfallTypes": ["C", "I"],
  "subtitle": "方向诱导、回环地图、假墙与隐形台阶",
  "trollQuote": "你以为右边铺满鲜花和金币是新手教程？向右走到尽头只会绕回起点，真正的梯子藏在左侧流动星尘的紫墙背后！",
  "spawn": {"x": 0.0, "y": 2.0},
  "bounds": {"minX": -15.0, "maxX": 30.0, "minY": -4.0, "maxY": 16.0},
  "props": {
    "abilities": ["move", "jump", "shoot", "interact"],
    "gravity": 1.0,
    "timeLimit": -1,
    "dualLayer": false,
    "bossId": ""
  },
  "hint_tiers": {
    "light": "观察左侧紫色墙体的粒子流动方向，再看看右侧金币路尽头连向哪里。",
    "medium": "右路是短回环且假旗会把你送回起点；紫墙上半段可穿过，墙后有隐藏砖与隐形台阶。",
    "full": [
      "① 先向右走到金币弧线末端体验回环（不要贪恋假旗与花丛），回到左侧紫墙前。",
      "② 站在紫墙边向上跳穿过上半段假墙，顶出墙后隐藏砖使第一块隐形台阶显形。",
      "③ 沿左上方隐形台阶登顶，从真旗背面落到真旗底座通关（勿碰右侧展示假旗）。"
    ]
  },
  "hintSteps": [
    "① 先向右走到金币弧线末端体验回环，回到左侧流动粒子的紫墙前。",
    "② 跳起穿过紫墙上半段无碰撞假墙，顶出隐藏砖显形第一级隐形台阶。",
    "③ 沿左上隐形台阶登顶，从背面落上真旗底座通关。"
  ],
  "hintIllust": "hint_ill_reverse",
  "checkpoints": [
    {"uuid": "lv001_cp_01", "x": -3.5, "y": 5.5, "saveStates": ["revealed_invis", "logic_flags"]}
  ],
  "collectibles": [
    {"uuid": "lv001_shard_01", "t": "mem_shard", "x": 24.0, "y": 5.5, "optional": true}
  ],
  "completion_rule": {
    "type": "flag_back_approach",
    "target_uuid": "lv001_real_flag",
    "anti_troll_medal_cond": "no_fake_flag_touch"
  },
  "solution_steps": [
    {"step": 1, "action": "loop_right_observe_or_go_left", "target": "lv001_fake_wall"},
    {"step": 2, "action": "hit_hidden_qblock", "target": "lv001_hidden_q1"},
    {"step": 3, "action": "climb_invis_stairs", "target": "lv001_invis_3"},
    {"step": 4, "action": "touch_flag_from_back", "target": "lv001_real_flag"}
  ],
  "logic_graph": [
    {"id": "lg_reveal_stair1", "trigger_uuid": "lv001_hidden_q1", "event": "on_hit", "target_uuid": "lv001_invis_1", "action": "reveal"}
  ],
  "objs": [
    {"uuid": "lv001_obj_01", "t": "solid", "x": -4.0, "y": 0.0, "w": 32.0, "h": 2.0, "skin": "steel"},
    ...
  ]
}
```

### 坐标系约定（与原版 48px/格 100% 兼容）
- `x` 向右递增（1.0 = 48px）；`y` **向上递增**（`y: 0, h: 2` 表示顶面在地面 `y = 2.0` 处；角色出生点 `spawn: {"x": 0, "y": 2}` 表示双脚站在 `y = 2.0` 地面上！）。
- 单次普通跳最大上升高度约 `3.1` 格、水平跨度约 `4.5` 格；二段跳总高度约 `5.4` 格；普通弹簧 `spring` 弹高约 `6.8` 格。**布置所有平台、高墙、深坑时必须确保物理跳跃可达，绝不制造超距死跳或像素跳！**
- 每个对象 `objs[i]` **必须包含唯一稳定字符串 `"uuid"`**（如 `"lv004_obj_07"`）以及类型 `"t"`、坐标 `"x"`, `"y"`（矩形地形含 `"w"`, `"h"`）。
- 支持全部 98 种原版 `t` 类型，并支持通过子属性扩展 v2.0 细分机制：
  - `cloud` / `s3_cloud`: `"subType": "solid" | "blade" | "hollow" | "bounce" | "thunder"`，`"brittleCore": true`
  - `sign`: `"mode": "truth" | "lie" | "fall_slope" | "wire_shock" | "reverse_grammar"`，`"text": "..."`
  - `flower` / `s3_flower`: `"subType": "skull" | "spore_giver" | "white_cure_aggro" | "magnetic" | "predictive" | "polite_reflect" | "flag_biter"`
  - `launcher`: `"period": 2.4`, `"dir": 1 | -1`, `"missileTypes": ["cracked", "cooled_rideable", "homing_bait"]`
  - `flag` / `mimic_flag` / `s3_mimic_flag`: `"fake": true | false`, `"fakeType": "loop_back" | "freeze_taunt" | "tentacle_back" | "fleeing" | "mimic_action"`, `"requireBackEntry": true | false`
  - `clock` / `beat_clock`: `"scope": "enemy_speed" | "mech_freeze" | "timer_only" | "rewind_plat" | "time_loan"`, `"group": "clk_a"`
  - `mirror`: `"rotatable": true`, `"angle": 45`, `"reflectsBomb": true`
  - `weight_scale` (或 `solid` + `"role": "weight_scale"`): `"targetWeight": 2`, `"linkedGateUuid": "..."`
  - `spotlight` (或 `signal_node` + `"role": "spotlight"`): `"castsShadow": true`, `"destructible": true`
  - `fake_error`: `"popupType": "normal_x" | "rogue_walkable" | "wire_pushable" | "load_bearing"`
  - `root_term`: `"permModes": ["READ", "WRITE", "ADMIN"]`, `"sheatheRequired": true | false`
  - `s2_boss` / `s3_boss` / `enemy_boss`: `"bossKey": "lv010_grad" | "lv020_gate" | "lv030_fortress" | "lv038_mechaskull" | "lv040_museum" | "lv050_author" | "lv060_signal" | "lv070_mecha" | "lv080_fracture" | "lv090_chrono" | "lv100_null" | "lv110_cloud_ram" | "lv120_hydra_pipe" | "lv130_kitsune_tanuki" | "lv140_thunder_demon" | "lv150_solaris"`

---

## 三、GDScript 4.2 严格编码铁律（子智能体 4 必读）
1. **严禁使用 `:=`**：Godot 4.2 Headless 在遇到 `Dictionary` / `Array` / `Variant` 返回值时使用 `:=` 会直接报编译错误退出。所有变量一律显式声明类型（如 `var x: float = float(d.get("x", 0.0))`）或使用无类型 `var x = ...`。
2. 所有贴图通过 `res://data/game_metadata.json` 中的 `assets` 字典加载，绘制时保持像素清晰（`TEXTURE_FILTER_NEAREST`）。
3. 必须支持命令行 `--smoke-test` 参数：在 Headless 模式下自动加载全部 150 关、运行 `LevelValidator`、模拟关键物理步进/状态转换/Boss 机制并打印 `[SMOKE TEST PASS] 150/150 levels verified`。
