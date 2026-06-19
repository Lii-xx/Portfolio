# Godot 卡牌肉鸽游戏 — 项目现状文档

> **用途**：本文件供新对话的 AI 在开始工作前完整阅读，以全面、准确、无误地了解项目当前进展、代码真实状态、已知问题、待办任务与开发约束。
> **生成时间**：2026-06-20
> **当前 HEAD commit**：`4f1bb47 feat: T3 核心动效 + 修复荆棘/中毒/盾反击杀卡关`
> **工作目录**：`D:\Desktop\求职\个人网站开发\game-godot\`

---

## 一、项目概览

### 1.1 这是什么

一个用 **Godot 4.6** 开发的卡牌肉鸽（Roguelike Card Game）游戏，是从同目录下的 HTML 版本（`个人网站-编辑区/`）移植/重构而来。游戏核心循环：每层（floor）面对一组怪物 → 出牌攻击/格挡 → 击杀全部怪物 → 获得卡牌奖励 → 进入下一层。中途有篝火（campfire）事件和延迟奖励机制。

### 1.2 技术栈

- **引擎**：Godot 4.6（`project.godot` 声明 `Forward Plus`，但实际 `rendering/rendering_method="gl_compatibility"`，**所有 shader 必须兼容 gl_compatibility**）
- **语言**：GDScript 4.x（静态类型）
- **分辨率**：1280×720，stretch mode = `canvas_items`
- **项目名**：CardRoguelike
- **主场景**：`res://scenes/main.tscn`

### 1.3 Autoload 单例（7 个，在 `project.godot` 注册）

| 名称 | 脚本 | 职责 |
|------|------|------|
| EventBus | `scripts/autoload/event_bus.gd` | 全局信号总线，逻辑层与表现层解耦 |
| CardRegistry | `scripts/autoload/card_registry.gd` | 卡牌数据注册（从 `data/cards/*.json` 加载） |
| MonsterRegistry | `scripts/autoload/monster_registry.gd` | 怪物数据注册（从 `data/monsters/*.json` 加载） |
| EncounterRegistry | `scripts/autoload/encounter_registry.gd` | 遭遇数据注册（从 `data/encounters.json` 加载） |
| EffectRegistry | `scripts/autoload/effect_registry.gd` | 卡牌效果注册（14 个效果类） |
| SoundManager | `scripts/autoload/sound_manager.gd` | 音效播放（文件不存在时静默跳过） |
| GameManager | `scripts/autoload/game_manager.gd` | 游戏核心状态机与战斗逻辑（最大单例，18KB） |

### 1.4 与 HTML 版本的关系

工作区根目录 `D:\Desktop\求职\个人网站开发\` 下有 `个人网站-编辑区/`（HTML 版成品，CSS 精致）和多个 `.html` 文件（`game.html`、`decon-gacha.html`、`decon-tft-economy.html` 等）。Godot 游戏在 `game-godot/` 子目录。**HTML 版本是设计参考与美术基准，Godot 版本目前美术精致度远不及 HTML，这是正常的阶段性状态（详见第八节"已知问题"）。**

---

## 二、目录结构（game-godot/）

```
game-godot/
├── project.godot                  # 引擎配置（7 autoload, 1280x720, gl_compatibility）
├── PROJECT_STATUS.md              # 本文件
├── scripts/
│   ├── main.gd                    # 根节点脚本，挂载在 main.tscn，处理 F11 全屏等
│   ├── autoload/                  # 7 个单例（见 1.3）
│   │   ├── event_bus.gd           # 30 个信号（见第六节）
│   │   ├── game_manager.gd        # 核心状态机 18KB
│   │   ├── sound_manager.gd       # T1 音效框架
│   │   ├── card_registry.gd
│   │   ├── monster_registry.gd
│   │   ├── encounter_registry.gd
│   │   └── effect_registry.gd     # 3KB，注册 14 个效果
│   ├── battle/
│   │   ├── damage_calculator.gd   # 伤害计算（apply_damage_to_monster 等）
│   │   └── intent_system.gd       # 怪物意图系统
│   ├── card_effects/              # 14 个卡牌效果类（每个 extends base_card_effect）
│   │   ├── base_card_effect.gd    # 基类
│   │   ├── bloodthirst_effect.gd
│   │   ├── dice_effect.gd         # 4.2KB（最复杂的效果）
│   │   ├── fate_wheel_effect.gd
│   │   ├── lifesteal_effect.gd
│   │   ├── lucky_draw_effect.gd
│   │   ├── poison_spread_effect.gd
│   │   ├── replay_effect.gd
│   │   ├── shield_counter_effect.gd
│   │   ├── show_fangs_effect.gd
│   │   ├── spin_effect.gd
│   │   ├── strength_effect.gd
│   │   ├── thorn_armor_effect.gd
│   │   └── triple_hit_effect.gd
│   ├── ui/                        # 表现层（10 个 UI 脚本）
│   │   ├── battle_screen.gd       # 30KB ~860行，战斗主屏幕（最核心文件）
│   │   ├── card_ui.gd             # 10KB，单张卡牌 UI（含拖拽源、T6 图片、T3 出牌动画）
│   │   ├── monster_slot.gd        # 10KB，单个怪物槽位（T5 着色器、受击/死亡动画）
│   │   ├── top_bar.gd             # 11.5KB，顶部栏（HP/护盾光环，注意：能量不在此）
│   │   ├── action_bar.gd          # 3.4KB，行动栏
│   │   ├── drag_system.gd         # 6.3KB，拖拽系统（重构时新增）
│   │   ├── reward_modal.gd        # 7KB，奖励弹窗
│   │   ├── campfire_screen.gd     # 篝火事件屏
│   │   ├── end_screen.gd          # 结算屏
│   │   └── title_screen.gd        # 标题屏
│   └── utils/
│       ├── tween_helpers.gd       # 4.4KB，10 个动效函数（T3 扩展）
│       ├── json_loader.gd         # JSON 加载工具
│       └── sprite_helper.gd       # 精灵加载工具
├── data/
│   ├── cards/                     # 20 张卡牌 JSON（strike, defend, cleave, ... ）
│   ├── monsters/                  # 10 个怪物 JSON（goblin, skeleton, ... abyss_lord）
│   ├── encounters.json            # 12 个遭遇定义
│   ├── campfire.json              # 篝火事件
│   ├── rewards.json               # 奖励池
│   └── delayed_rewards.json       # 延迟奖励
├── shaders/                       # 5 个着色器
│   ├── hit_flash.gdshader         # T5：受击闪白
│   ├── dissolve.gdshader          # T5：死亡溶解
│   ├── poison.gdshader            # T5：中毒变绿
│   ├── shield.gdshader            # T5：护盾光环
│   └── crt_scanlines.gdshader     # CRT 扫描线（独立氛围滤镜，非 T5 产物）
├── scenes/
│   ├── main.tscn                  # 7.4KB，根场景（挂 main.gd，组织各子屏）
│   └── title_screen.tscn          # 标题屏场景
└── assets/
    └── audio/
        ├── sfx/                   # 只有 _placeholder.txt，无实际音频文件
        └── bgm/                   # 只有 _placeholder.txt，无实际音频文件
```

**说明**：`scenes/` 只有 2 个 `.tscn`。`BattleScreen`/`MonsterSlot`/`CardUI`/`TopBar` 等 UI 节点由代码动态创建或在 `main.tscn` 内组织（新 AI 需要时直接读 `main.tscn` 确认结构）。

---

## 三、Git 提交历史（完整，共 8 个 commit）

```
4f1bb47 feat: T3 核心动效 + 修复荆棘/中毒/盾反击杀卡关   ← HEAD（本次）
1a3336a feat: 卡牌系统重构 + T1/T5/T6 美术开发框架
2b66b7f 清理误提交的缓存与临时文件
d67314b 首页及卡牌demo调整
b5b3b02 1.1更新情况
e9d7604 改了整体页面风格以及demo上的怪物显示
293f816 Add files via upload
eb4d9b1 init: card game demo project
```

### 当前工作区状态

- `game-godot/` 下三个文件已提交（battle_screen.gd / card_ui.gd / tween_helpers.gd），工作区干净。
- `godot-mcp/`（submodule）有 modified content —— **这是 MCP 工具的改动，与游戏无关，不要 commit**。
- `个人网站-编辑区/`（未跟踪）—— HTML 版本，与 Godot 游戏无关。
- 本地分支 `main` 领先 `origin/main` 2 个 commit（1a3336a 和 4f1bb47 未 push）。

---

## 四、已完成任务清单（详细）

### 4.1 卡牌系统重构（commit `1a3336a`，最早完成）

- 删除 3 张旧卡，新增 9 张新卡（现共 20 张）
- 新增拖拽系统 `drag_system.gd`（6.3KB）
- 战斗流程调整（出牌→确认→结算→怪物回合）
- 与 HTML 版本对齐机制（荆棘反伤、中毒、獠牙被动、盾反等）

### 4.2 T1 音效框架（commit `1a3336a`）

**目标**：搭建音效播放框架，不包含实际音频文件。

**改动**：
- 重写 `sound_manager.gd`：路径表 + 缓存 + **文件不存在时静默跳过**（`play_sfx` 里 `if stream == null: return`）
- 接入 EventBus 的 `sfx_requested` / `bgm_requested` / `bgm_stopped` 信号
- 在 `battle_screen.gd` / `card_ui.gd` / `monster_slot.gd` 等 16 处调用 `EventBus.sfx_requested.emit("xxx")`

**关键设计**：音效名是字符串（如 `"player_hurt"`、`"attack_hit"`、`"monster_die"`、`"block"`、`"debuff"`、`"poison"`、`"attack_heavy"`），由 SoundManager 映射到文件路径。**现在所有 emit 都在正常发射，只是加载不到文件所以静默**。

**未完成**：`assets/audio/sfx/` 和 `bgm/` 目录只有 `_placeholder.txt`，需要 T2 填入实际 `.wav`/`.ogg` 文件。

### 4.3 T5 着色器（commit `1a3336a`）

**目标**：4 个战斗特效着色器 + 接入 UI。

**改动**：
- 新增 4 个 `.gdshader`：`hit_flash`（受击闪白）、`dissolve`（死亡溶解）、`poison`（中毒变绿）、`shield`（护盾光环）
- `monster_slot.gd`：接入 hit_flash/dissolve/poison，加 `_is_dying` 标志防止溶解被其他动画覆盖
- `top_bar.gd`：加 `_shield_mat` 护盾光环材质

**兼容性**：所有 shader 兼容 `gl_compatibility` 渲染器。

**注意**：`crt_scanlines.gdshader` 是独立存在的第 5 个 shader（CRT 扫描线氛围滤镜），**不是 T5 产物**，可能是更早做的，改动时注意区分。

### 4.4 T6 卡牌图代码支持（commit `1a3336a`）

**目标**：让卡牌 UI 支持加载图片，但暂不填入实际图片。

**改动**：
- `card_ui.gd`：新增 `art_rect`（TextureRect）节点用于显示卡牌图
- 20 张卡牌 JSON 全部新增 `"art": ""` 字段（空字符串，表示无图）

**未完成**：所有 `art` 字段为空，需要后续填入实际图片路径。

### 4.5 T3 核心动效 P0（commit `4f1bb47`）

**目标**：核心战斗动效（出牌飞行、屏幕震动、能量跳动）。

**改动**：
- `tween_helpers.gd`：
  - 新增 `card_play_to_target(card, target_pos)` — 卡牌飞向目标后缩小消失，末尾 `visible=false` 防闪烁
  - 新增 `screen_shake(node, intensity, duration)` — 屏幕震动，4 次随机偏移后归位
  - 新增 `energy_spend(label)` — 能量数字跳动 scale 1→1.5→1.0，设了中心 pivot
  - 修改 `monster_hit_shake(node)` — **删除了 modulate 闪白部分**（由 T5 hit_flash 着色器接管），只保留抖动
- `card_ui.gd`：新增 `play_card_animation(target_pos)` 公开方法，内部调 `TweenHelpers.card_play_to_target`
- `battle_screen.gd`：
  - `_on_confirm_pressed()` — 出牌时查找对应 card_ui，飞向怪物槽位（`_monster_slots[target_idx].global_position + Vector2(60, 90)`），`await 0.4s` 后再播 `_play_card_events`
  - `_play_card_events()` — AOE 卡牌开头加 `screen_shake(self, 10.0, 0.3)`
  - `_do_monster_turn()` — `monster_atk` 事件加 `screen_shake(self, 6.0, 0.2)`（玩家受伤轻震）
  - `_refresh_actions()` — 能量减少时调 `energy_spend(turn_hint)`，用 `_prev_energy` 对比

**T3 后 `tween_helpers.gd` 共 10 个函数**：`card_hover`、`card_selected`、`monster_hit_shake`、`damage_popup`、`hp_bar_smooth`、`monster_death`、`button_step_hover`、`card_play_to_target`、`screen_shake`、`energy_spend`。

**待确认事项**（需人工视觉验证，新 AI 若收到反馈需处理）：
1. 出牌飞行目标位置偏移 `Vector2(60, 90)` 是估算的怪物中心，若不准需调整
2. 能量跳动 pivot 设了 `label.pivot_offset = label.size / 2`，若位置不对需调整

### 4.6 Bug 1 修复（commit `4f1bb47`，致命 bug）

**问题**：荆棘/中毒/盾反击杀怪物后，游戏卡关无奖励，无法推进。

**根因**（`battle_screen.gd` 的 `_do_monster_turn` 函数两处缺陷）：
1. 怪物行动事件循环只 match 了 `monster_atk` / `debuff` / `monster_def` 三个 case，**缺少 `thorn_dmg` / `poison_dmg` / `kill`**。而 `game_manager.gd` 的 `monster_turn()` 会生成这三种事件（`thorn_dmg` 在 260 行、`poison_dmg` 在 241 行、`kill` 在 243/262 行）。导致荆棘/中毒伤害无视觉反馈、击杀无死亡动画。
2. 函数末尾只有玩家死亡判定，**缺少 `check_combat_win` 胜利判定**。对比 `_play_card_events` 末尾是有这个判定的。导致 `combat_won` 信号永不发出 → 卡关。

**修复**（commit `4f1bb47`）：
- 事件循环补 `thorn_dmg` / `poison_dmg` / `kill` 三个 case，参照 `_play_card_events` 的 `dmg`/`kill` 写法（调 `play_hit_animation(val)` + 伤害弹出 + 音效 / `play_death_animation()` + 音效）
- 末尾补 `if GameManager.check_combat_win(): EventBus.combat_won.emit()`（并在玩家死亡分支加 `return` 防止后续误判）

**验证**：字段名已核对（`game_manager.gd` 的 `thorn_dmg`/`poison_dmg` 事件含 `idx`+`value` 字段，`kill` 含 `idx` 字段，与修复代码匹配）。`play_hit_animation(damage: int)` 接受 int 参数，`play_death_animation()` 无参，签名匹配。lints 无错误。

**仍需人工验证**：带荆棘护甲卡打怪，确认反伤弹数字 + 怪物死亡触发下一关。

---

## 五、关键文件真实状态（新 AI 必读）

### 5.1 `scripts/ui/battle_screen.gd`（30KB，~860 行，最核心文件）

**职责**：战斗主屏幕，协调出牌、动画播放、回合切换、胜负判定。

**关键函数与行号**（行号会随改动变化，仅供参考定位）：
- `_on_confirm_pressed()` — 出牌确认，含 T3 出牌飞行动画 + `await 0.4s`
- `_play_card_events()` — 播放出牌事件，含 AOE 震动，末尾有 `check_combat_win` 胜利判定（约 680 行）
- `_do_monster_turn()` — 播放怪物回合事件，**Bug1 已修复**：含 thorn_dmg/poison_dmg/kill case + 末尾 check_combat_win（约 718-755 行）
- `_delayed_action(delay, action)` — 用 `create_timer` 延迟执行，事件动画的时序基础
- `_refresh_actions()` — 刷新行动栏，含 T3 能量跳动（用 `_prev_energy` 对比）
- `_on_combat_won()` / `_on_combat_lost()` — EventBus 回调
- `_input(event)` — 处理战斗内输入（约 790 行，注意与 main.gd 的 _input 共存）

**重要**：`_monster_slots` 是怪物槽位数组，`play_hit_animation(val)` / `play_death_animation()` 是其元素（monster_slot.gd）的方法。

### 5.2 `scripts/autoload/game_manager.gd`（18KB，核心状态机）

**职责**：游戏状态、战斗逻辑、回合管理。

**关键点**：
- `state` 字典：包含 `player`（hp/block/thorn_buff/poison/strength 等）、`monsters`（数组）、`floor`、`animating` 等
- `monster_turn()` — 生成怪物回合事件数组，**会生成 `poison_dmg`(241行) / `thorn_dmg`(260行) / `kill`(243/262行) 事件**，BattleScreen 必须全部处理（Bug1 已修）
- `check_combat_win()` — 检查所有怪物是否死亡，返回 bool
- `start_turn()` — 清格挡、应用延迟奖励
- `save_high_score()` — 保存最高分
- 盾反事件 `shield_events` 在 `end_turn()` 阶段生成（292-293行）

### 5.3 `scripts/ui/monster_slot.gd`（10KB）

**关键方法**：
- `play_hit_animation(damage: int)` — 调 `TweenHelpers.monster_hit_shake` + `damage_popup` + `_update_hp`
- `play_death_animation()` — 设 `_is_dying=true` + `_play_dissolve()`（T5） + `TweenHelpers.monster_death`
- T5 着色器：hit_flash / dissolve / poison，`_is_dying` 防溶解被覆盖

### 5.4 `scripts/ui/card_ui.gd`（10KB）

- `extends Panel`
- T6：有 `art_rect`（TextureRect）显示卡牌图（art 字段当前全空）
- T3：有 `play_card_animation(target_pos)` 方法
- **注意**：没有 `_build_ui` 函数（UI 在 `_ready` 或内联构建）

### 5.5 `scripts/ui/top_bar.gd`（11.5KB）

- T5：有 `_shield_mat` 护盾光环材质
- **重要**：能量（energy）显示在 `turn_hint` 节点，**不在 top_bar**。T3 的 `energy_spend` 作用对象是 `turn_hint`。

### 5.6 `scripts/utils/tween_helpers.gd`（4.4KB，10 个函数）

完整函数清单：`card_hover`、`card_selected`、`monster_hit_shake`（T3 删除了 modulate 闪白）、`damage_popup`、`hp_bar_smooth`、`monster_death`、`button_step_hover`、`card_play_to_target`（T3）、`screen_shake`（T3）、`energy_spend`（T3）。

### 5.7 `scripts/autoload/sound_manager.gd`（3.4KB）

- T1 重写
- `play_sfx(sfx_name)` — 从 `_sfx_cache` 取，`if stream == null: return` 静默跳过
- **当前所有音效静默**，因为 `assets/audio/` 下无实际文件

### 5.8 `scripts/main.gd`

- 挂在 `main.tscn` 根节点
- `_input` 处理 `KEY_F11` → `_toggle_fullscreen()`（切换 WINDOW_MODE_FULLSCREEN / WINDOWED）
- **Bug2**：F11 可能不生效（详见第八节）

### 5.9 `scripts/autoload/event_bus.gd`（30 个信号）

完整信号清单（新 AI 接信号时参照）：
- **战斗**：`card_played(card_id, target_idx, events)`、`card_selected`、`card_selection_cleared`、`confirm_play_requested`、`turn_skipped`、`monster_damaged`、`monster_killed`、`monster_blocked`、`player_damaged`、`player_healed`、`player_block_gained`、`buff_applied`、`debuff_applied`、`combat_won`、`combat_lost(floor)`、`victory`
- **回合**：`turn_started`、`turn_ended`、`phase_changed(phase)`
- **元游戏**：`campfire_entered`、`campfire_choice_made`、`reward_shown`、`reward_picked`、`delayed_reward_picked`、`sacrifice_entered`、`sacrifice_completed`、`blank_convert_requested`
- **屏幕**：`screen_requested`、`game_started`、`game_restart_requested`、`title_requested`
- **音效**：`sfx_requested(sfx_name)`、`bgm_requested(bgm_name)`、`bgm_stopped`

**注意**：部分信号当前未被使用（如 `monster_damaged`/`monster_killed` 等，BattleScreen 直接调 monster_slot 方法而非走信号），运行时会有"未使用信号"警告，**这是预存警告，不是错误**。

---

## 六、数据文件清单

### 6.1 卡牌（20 张，`data/cards/*.json`）

`blank`、`bloodthirst`、`cleave`、`combo_slash`、`defend`、`dice`、`dual`、`fate_wheel`、`iron_shield`、`iron_wall`、`lucky_draw`、`poison_spread`、`replay`、`shield_counter`、`show_fangs`、`spin`、`strike`、`thorn_armor`、`vampiric`、`war_cry`

每张卡 JSON 含 `art: ""` 字段（T6，当前全空）。效果由 `card_effects/` 下 14 个效果类实现（部分卡如 strike/cleave/defend 用通用伤害/格挡逻辑，无独立效果文件）。

### 6.2 怪物（10 个，`data/monsters/*.json`）

`goblin`、`skeleton`、`orc`、`rogue`、`werewolf`、`frost_giant`、`flame_warlock`、`dark_mage`、`shadow_dragon`、`abyss_lord`（boss，467B 最大）

### 6.3 其他

- `encounters.json` — 12 个遭遇定义
- `campfire.json` — 篝火事件
- `rewards.json` — 奖励池
- `delayed_rewards.json` — 延迟奖励

---

## 七、游戏机制说明（重要约束，新 AI 必须遵守）

1. **没有抽牌机制** —— 所有卡牌每回合直接全部在手牌上显示。不要尝试实现抽牌/弃牌/牌堆逻辑。`card_draw` 动效在 T3 已明确跳过。
2. **KEY_K 是开发调试键** —— 秒杀当前怪物，会跳过出牌流程。**不能用于测试出牌动效**。测试出牌必须正常拖牌→确认。
3. **能量显示在 `turn_hint` 节点**，不在 `top_bar`。T3 的 `energy_spend` 作用对象是 `turn_hint`。
4. **渲染器是 `gl_compatibility`** —— 所有 shader 必须兼容此渲染器，不能用 Forward Plus 专属特性。
5. **事件驱动动画** —— `game_manager.gd` 生成事件数组（`dmg`/`kill`/`thorn_dmg`/`poison_dmg`/`monster_atk`/`debuff`/`monster_def`/`shield_events` 等），`battle_screen.gd` 的 `_play_card_events` / `_do_monster_turn` 负责消费这些事件播动画。**新增事件类型时，两边的 case 必须同步**（Bug1 就是不同步导致的）。
6. **延迟动画时序** —— 用 `_delayed_action(delay, action)`（基于 `create_timer`）排队，`delay` 累加。胜负判定放在最后一个 `_delayed_action` 内。
7. **荆棘/中毒/盾反** —— 这些机制在 `game_manager.gd` 生成独立事件，UI 必须处理（Bug1 已修复，新 AI 改动 `_do_monster_turn` 时切勿删除这些 case）。

---

## 八、已知问题与 Bug

### 8.1 [已修复] Bug 1：荆棘/中毒/盾反击杀卡关（致命）

见 4.6 节。已在 commit `4f1bb47` 修复，**仍需人工视觉验证**（带荆棘护甲打怪，确认反伤弹数字 + 死亡触发下一关）。

### 8.2 [低优先级-未修] Bug 2：F11 全屏可能不生效

**现象**：按 F11 无法全屏。

**代码层面**：`main.gd` 的 `_input` 正确匹配 `KEY_F11` 并调 `_toggle_fullscreen()`，逻辑无误。

**可能原因**：
1. Godot 编辑器运行时拦截了 F11
2. `BattleScreen` 也有 `_input`（约 790 行），可能抢先消费或干扰
3. `DisplayServer` 在 Windows 环境下行为异常

**排查建议**：
- 运行游戏后看控制台是否打印 `[Main] Switched to fullscreen mode`（有打印但没全屏 → DisplayServer 问题；没打印 → `_input` 没触发）
- 把 `main.gd` 的 `_input` 改成 `_unhandled_input` 试试
- 导出 exe 后测 F11（排除编辑器拦截）

**优先级**：低，不阻塞游戏。新 AI 可顺手处理。

### 8.3 [非 Bug] 无音效

`assets/audio/sfx/` 和 `bgm/` 只有 `_placeholder.txt`，无实际音频文件。SoundManager 静默跳过是设计行为。需要 T2 填入音频资源。

### 8.4 [非 Bug] 美术精致度不及 HTML 版本

当前 Godot 版本是纯代码 UI 骨架：
- 卡牌图：T6 加了 TextureRect，但 20 张 JSON 的 `art` 字段全空
- 字体：用 Godot 默认字体（HTML 版用了 CSS 字体）
- 动效：T3 刚做完（出牌飞行/震动/能量跳动），T4 粒子 / T10 氛围动效未做
- 着色器：T5 做了 4 个（闪白/溶解/中毒/护盾），需配合实际美术资源体现

需要 T2/T4/T7/T8/T9/T10 逐步完成后才能追上 HTML 版本。

### 8.5 [预存警告] EventBus 未使用信号

部分 EventBus 信号未被连接（如 `monster_damaged`/`monster_killed` 等），运行时有警告。**这不是错误，不影响运行**，是新架构（信号解耦）与旧调用方式（直接调方法）并存的过渡现象。

### 8.6 [预存警告] end_screen 参数名

`end_screen.gd` 有参数名相关警告，与功能无关。

---

## 九、待办任务清单（按依赖关系排序）

### 任务依赖关系图

```
T3(完成) ──┬──> T4(粒子)        ──┐
           └──> T10(氛围动效)    ──┼──> 都改 battle_screen.gd，必须串行
T8(背景图,独立) ─────────────────┘

T2(音频资源)  ─┐
T7(字体)      ─┼──> 资源填入类，相互独立，可并行，也可与上面并行
T9(怪物图)    ─┘

Bug2(F11) ──> 低优先级，顺手修
```

### 9.1 T2 音频资源（独立，可并行）

**目标**：为 SoundManager 填入实际音频文件，让游戏有声音。

**做法**：
- 准备 `.wav`/`.ogg` 音频文件放入 `assets/audio/sfx/` 和 `bgm/`
- 音效名需与代码中 `EventBus.sfx_requested.emit("xxx")` 的字符串对应（如 `player_hurt`、`attack_hit`、`attack_heavy`、`monster_die`、`block`、`debuff`、`poison`）
- 可能需调整 `sound_manager.gd` 的路径映射表

**注意**：先读 `sound_manager.gd` 确认路径表与命名约定。

### 9.2 T4 粒子（依赖 T3，改 monster_slot.gd / battle_screen.gd）

**目标**：战斗粒子特效（受击火星、死亡爆散、护盾碎裂等）。

**注意**：与 T10/T8 都改 `battle_screen.gd`，**不可并行，必须串行**。

### 9.3 T10 氛围动效（依赖 T3，改 tween_helpers.gd / monster_slot.gd / battle_screen.gd）

**目标**：背景氛围动效（浮动光点、呼吸光晕等），提升精致度。

**注意**：与 T4/T8 都改 `battle_screen.gd`，**不可并行，必须串行**。

### 9.4 T8 背景图（独立但轻，改 battle_screen.gd / encounters.json）

**目标**：为不同遭遇/楼层添加背景图。

**注意**：与 T4/T10 都改 `battle_screen.gd`，**不可并行，必须串行**。

### 9.5 T7 字体（独立，可并行）

**目标**：替换 Godot 默认字体，对齐 HTML 版本风格。

**做法**：准备 `.ttf`/`.otf` 字体文件，在 `project.godot` 或主题中配置。

### 9.6 T9 怪物图（独立，可并行）

**目标**：为 10 个怪物填入图片。

**做法**：
- 准备怪物图片放入 `assets/`
- 在 `data/monsters/*.json` 填入图片路径字段（需先确认 monster_slot.gd 是否已支持图片加载，若无则需补代码）
- 注意 `monster_slot.gd` 的 dissolve/hit_flash 着色器要作用于怪物图

### 9.7 Bug 2 F11 全屏（低优先级，顺手修）

见 8.2 节排查建议。

### 推荐执行顺序

1. **先人工验证 Bug 1 修复**（带荆棘打怪）—— 若有问题立即修
2. T4（粒子）
3. T10（氛围动效）
4. T8（背景图）
5. T2 / T7 / T9 可与上述并行（资源填入类）
6. Bug2 顺手修

**关键约束**：T4/T10/T8 串行（都改 battle_screen.gd）；T2/T7/T9 可并行。

---

## 十、开发约定与注意事项（新 AI 必读）

### 10.1 不要做的事

1. **不要 commit `godot-mcp/`**（submodule）的改动 —— 那是 MCP 工具，与游戏无关。
2. **不要 commit `个人网站-编辑区/`** 或根目录的 `.html` 文件 —— 那是 HTML 版本，与 Godot 游戏无关。
3. **不要实现抽牌/牌堆机制** —— 本游戏所有牌每回合全在手牌。
4. **不要用 KEY_K 测试出牌动效** —— 它秒杀跳过出牌流程。
5. **不要删除 `_do_monster_turn` 的 thorn_dmg/poison_dmg/kill case** —— Bug1 刚修，删了会复发卡关。
6. **不要在没有读文件的情况下编辑** —— Godot 文件改动频繁，先 `read_file` 确认真实内容。
7. **不要并行编辑 `battle_screen.gd`** —— 多任务改同一文件必须串行，否则冲突。

### 10.2 要做的事

1. **改文件前先 `read_file`** —— 确认当前真实内容（行号会变）。
2. **改完用 `read_lints`** 检查语法错误。
3. **改完用 `run_project`** 验证启动无报错（Godot 4.6）。
4. **shader 必须兼容 `gl_compatibility`**。
5. **新增事件类型时** —— `game_manager.gd` 生成 + `battle_screen.gd` 消费，两边 case 同步（Bug1 教训）。
6. **commit 时只 add `game-godot/` 下的具体文件**，不要 `git add -A`。
7. **commit message 用中文 + feat/fix 前缀**，参考历史 commit 风格。

### 10.3 工作流（每个任务）

1. `read_file` 读目标文件确认真实状态
2. `replace_in_file` 做针对性修改（不要整文件重写）
3. `read_lints` 检查错误
4. `run_project`（通过 godot-mcp）验证启动
5. 人工视觉验证（由用户做）
6. 用户确认后 `git add` + `git commit`

---

## 十一、新对话启动检查清单

新 AI 开始工作前，建议按此顺序确认：

1. **读本文档**（你正在读）
2. **`git log --oneline -3`** 确认 HEAD 是 `4f1bb47`（若有新 commit，以新 commit 为准）
3. **`git status`** 确认工作区是否干净（`godot-mcp` 的 modified 是正常的，忽略）
4. **`run_project`** 启动游戏，确认无报错（预存警告可忽略，见 8.5/8.6）
5. 根据用户要做的任务，`read_file` 读相关文件确认当前真实状态
6. 执行任务，遵循 10.2 工作流

### 常见任务快速入口

| 任务 | 先读哪些文件 |
|------|-------------|
| T4 粒子 | `monster_slot.gd`、`battle_screen.gd`、`tween_helpers.gd` |
| T10 氛围动效 | `tween_helpers.gd`、`battle_screen.gd`、`monster_slot.gd` |
| T8 背景图 | `battle_screen.gd`、`data/encounters.json` |
| T2 音频 | `sound_manager.gd`、`assets/audio/` 目录 |
| T7 字体 | `project.godot`、主题配置 |
| T9 怪物图 | `monster_slot.gd`、`data/monsters/*.json` |
| Bug2 F11 | `main.gd`、`battle_screen.gd` 的 `_input` |
| 战斗逻辑 bug | `game_manager.gd`、`battle_screen.gd`、`damage_calculator.gd` |

---

## 十二、本次（4f1bb47）改动摘要

本次 commit 包含两部分：

### A. T3 核心动效（3 文件）
- `tween_helpers.gd`：+3 函数（card_play_to_target/screen_shake/energy_spend），改 1 函数（monster_hit_shake 删 modulate 闪白）
- `card_ui.gd`：+play_card_animation 方法
- `battle_screen.gd`：接入震动（AOE/玩家受伤）、出牌飞行（await 0.4s）、能量跳动（_prev_energy 对比）

### B. Bug 1 修复（1 文件，battle_screen.gd）
- `_do_monster_turn` 事件循环补 `thorn_dmg`/`poison_dmg`/`kill` 三个 case
- `_do_monster_turn` 末尾补 `check_combat_win` 胜利判定 + 玩家死亡分支加 `return`

**commit 统计**：3 files changed, 85 insertions(+), 5 deletions(-)

**未 push**：本地 main 领先 origin/main 2 个 commit。

---

*文档结束。新 AI 读完此文档后，应能完整、准确、无误地了解项目现状，可直接执行用户分配的下一项任务。*
