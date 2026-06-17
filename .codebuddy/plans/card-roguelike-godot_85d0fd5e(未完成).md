---
name: card-roguelike-godot
overview: 将HTML卡牌Roguelike游戏转换为Godot 4项目，加入音效和轻量动效，保持原版核心玩法和视觉风格
todos:
  - id: init-godot-project
    content: Use [skill:godot-dev] 创建 Godot 项目并配置基础结构(AutoLoad/资源目录/精灵图导入)
    status: pending
  - id: data-and-game-logic
    content: Use [skill:godot-dev] 实现数据定义和游戏核心逻辑(卡牌/怪物/关卡/回合系统/存档)
    status: pending
    dependencies:
      - init-godot-project
  - id: battle-ui-and-scenes
    content: Use [skill:godot-dev] 构建战斗画面场景(TopBar/怪物区/手牌区/操作栏/CRT shader)
    status: pending
    dependencies:
      - data-and-game-logic
  - id: card-drag-and-interaction
    content: Use [skill:godot-dev] 实现卡牌拖拽交互和点击选牌系统
    status: pending
    dependencies:
      - battle-ui-and-scenes
  - id: effects-and-sound
    content: Use [skill:godot-dev] 添加动效(受击抖动/伤害飘字/Tween)和音效系统(攻击/防御/受击/BGM)
    status: pending
    dependencies:
      - battle-ui-and-scenes
  - id: meta-screens
    content: Use [skill:godot-dev] 实现标题画面/火堆/奖励弹窗/献祭/结算等元场景
    status: pending
    dependencies:
      - card-drag-and-interaction
  - id: integration-test
    content: Use [skill:godot-dev] 整合所有场景并测试完整游戏流程
    status: pending
    dependencies:
      - effects-and-sound
      - meta-screens
---

## 产品概述

将现有的 HTML 卡牌 Roguelike 游戏完整移植为 Godot 4 版本，保持核心玩法一致，增加轻微动效和音效体验。

## 核心功能

- 完整复刻 HTML 版的卡牌战斗系统：14种卡牌、10种怪物、12场战斗编排、火堆、献祭、空白牌兑换、奖励3选1
- 卡牌拖拽/点击交互出牌机制
- 回合制战斗流程：出牌→确认→怪物行动→下一回合
- 怪物意图预览系统（攻击/防御/减益循环）
- 赛博朋克像素风视觉风格（深紫底+霓虹绿/粉/青配色、CRT扫描线、像素字体）
- 新增轻微动效：卡牌悬停放大、受击抖动、伤害数字飘出、HP条平滑过渡、按钮步进动画
- 新增音效：攻击音效、防御音效、受击音效、减益音效、治疗音效、击杀音效、BGM
- 不需要角色帧动画或Spine动画
- 高分记录持久化

## 技术栈

- **引擎**: Godot 4.x（通过 godot-dev skill 部署和管理）
- **语言**: GDScript
- **渲染**: 2D（CanvasItem）
- **音频**: Godot AudioStreamPlayer / AudioStreamPlayerPolyphonic
- **动画**: Tween（代码驱动，不用AnimationPlayer节点）
- **持久化**: FileAccess JSON 文件存取（替代 localStorage）
- **素材**: 复用现有 monsters.png 精灵图、new background.png 背景

## 实现方案

### 整体策略

使用 godot-dev skill 创建完整 Godot 项目，采用场景树+单例的架构。游戏核心是一个状态机驱动的回合制系统，所有游戏数据（卡牌定义、怪物定义、关卡编排）用 GDScript 字典常量定义，与逻辑层解耦。UI 层通过信号与逻辑层通信。

### 场景结构设计

```
Main (Control) — 全局容器
├── Background (TextureRect) — 背景图 + CRT shader overlay
├── TitleScreen (Control) — 标题画面
├── BattleScreen (Control) — 战斗画面
│   ├── TopBar (HBoxContainer) — HP/格挡/力量/减益/层数
│   ├── MonsterArea (CenterContainer) — 怪物展示区
│   │   └── MonsterSlot (VBoxContainer) × N — 单个怪物槽位
│   ├── CardArea (VBoxContainer) — 手牌+操作栏
│   │   ├── CardHand (HBoxContainer) — 手牌容器
│   │   │   └── CardUI (Panel) × N — 单张卡牌
│   │   └── ActionBar (HBoxContainer) — 确认/取消/结束回合等
│   └── TurnHint (Label) — 回合提示
├── CampfireScreen (Control) — 火堆选择
├── RewardModal (Control) — 奖励弹窗
├── SacrificeOverlay (Control) — 献祭选择
├── GameOverScreen (Control) — 战败画面
└── VictoryScreen (Control) — 通关画面
```

### 核心架构

- **GameManager (AutoLoad)**: 游戏状态管理单例，包含玩家数据、当前战斗状态、卡组、怪物列表、回合逻辑
- **SoundManager (AutoLoad)**: 音效管理器，统一管理 BGM 和 SFX 播放
- **DataDefs (AutoLoad)**: 卡牌定义、怪物定义、关卡编排等常量数据
- 信号驱动：GameManager 发出信号（card_played, monster_attacked, combat_won 等），UI 节点监听并播放动效/音效

### 动效方案（全部用 Tween）

1. **卡牌悬停**: scale 1.0→1.1，0.1s，ease_out
2. **卡牌选中**: scale 1.0→1.12 + 上移8px，0.12s
3. **怪物受击**: position.x 抖动 ±8px 来回2次 + modulate 变白闪烁，0.15s
4. **伤害数字**: Label 从怪物上方飘出，向上35px + 透明度1→0，0.7s
5. **HP条**: value 平滑过渡，0.3s，ease_out
6. **按钮交互**: 步进式 hover（scale + 位移偏移），与原 HTML 的 steps(4) 一致
7. **怪物死亡**: modulate 渐变灰色 + opacity→0.25，0.3s
8. **玩家受击**: TopBar HP 区域短暂红色闪烁

### 音效方案

使用 Godot AudioStreamPlayer 播放：

1. **BGM**: 单曲循环低音量播放（暗色氛围循环）
2. **攻击音效**: 短促冲击音
3. **防御音效**: 金属碰撞音
4. **受击音效**: 沉重打击音
5. **减益音效**: 诡异低频音
6. **治疗音效**: 温和上升音
7. **击杀音效**: 爆裂音效
8. **UI交互音**: 按钮点击、卡牌选中等
9. **火堆音效**: 营火噼啪声

音效文件初期用 AudioStreamGenerator 合成简单波形占位，确保音效通路正确，后续可替换为正式音频文件。

### 数据持久化

用 `user://save_data.json` 存储最高通关层数，通过 FileAccess 类读写。

### 精灵图处理

monsters.png 为 5x2 网格，在 Godot 中用 AtlasTexture 或 Sprite2D + region_enabled 切割，根据 spriteIdx(0-9) 动态计算 region 位置。

## 目录结构

```
game-godot/
├── project.godot                    # [NEW] 项目配置，含 AutoLoad 注册
├── icon.svg                         # [NEW] 项目图标
├── assets/
│   ├── sprites/
│   │   └── monsters.png             # [COPY] 怪物精灵图(5x2)
│   ├── backgrounds/
│   │   └── battle_bg.png            # [COPY] new background.png 重命名
│   ├── fonts/
│   │   └── PressStart2P-Regular.ttf # [NEW] 像素风标题字体
│   └── audio/
│       ├── bgm/
│       │   └── battle_theme.ogg     # [NEW] 战斗BGM(合成占位)
│       └── sfx/
│           ├── attack.ogg           # [NEW] 攻击音效
│           ├── defend.ogg           # [NEW] 防御音效
│           ├── hit.ogg              # [NEW] 受击音效
│           ├── debuff.ogg           # [NEW] 减益音效
│           ├── heal.ogg             # [NEW] 治疗音效
│           ├── kill.ogg             # [NEW] 击杀音效
│           ├── ui_click.ogg         # [NEW] UI点击音
│           └── campfire.ogg         # [NEW] 火堆音效
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd          # [NEW] 游戏状态管理单例(核心逻辑)
│   │   ├── sound_manager.gd         # [NEW] 音效管理单例
│   │   └── data_defs.gd             # [NEW] 卡牌/怪物/关卡数据定义
│   ├── scenes/
│   │   ├── title_screen.gd          # [NEW] 标题画面脚本
│   │   ├── battle_screen.gd         # [NEW] 战斗画面主控脚本
│   │   ├── card_ui.gd               # [NEW] 卡牌UI脚本(拖拽+悬停动效)
│   │   ├── monster_slot.gd          # [NEW] 怪物槽位脚本(受击动效+伤害飘字)
│   │   ├── campfire_screen.gd       # [NEW] 火堆画面脚本
│   │   ├── reward_modal.gd          # [NEW] 奖励弹窗脚本
│   │   └── end_screen.gd            # [NEW] 结算画面脚本
│   └── utils/
│       └── tween_helpers.gd         # [NEW] Tween动效工具函数
├── scenes/
│   ├── main.tscn                    # [NEW] 主场景
│   ├── title_screen.tscn            # [NEW] 标题画面场景
│   ├── battle_screen.tscn           # [NEW] 战斗画面场景
│   ├── card_ui.tscn                 # [NEW] 卡牌UI子场景
│   ├── monster_slot.tscn            # [NEW] 怪物槽位子场景
│   ├── campfire_screen.tscn         # [NEW] 火堆画面场景
│   ├── reward_modal.tscn            # [NEW] 奖励弹窗场景
│   └── end_screen.tscn              # [NEW] 结算画面场景
└── shaders/
    └── crt_scanlines.gdshader       # [NEW] CRT扫描线shader
```

## 实现注意事项

1. **音效占位**: 初期用 AudioStreamGenerator 生成简单波形音效占位，确保音效系统通路正确，后续替换正式音频文件即可
2. **CRT Shader**: 用 CanvasItem shader 实现扫描线+径向暗角，与原 HTML 的 body::before/::after 对应
3. **卡牌拖拽**: 用 Input 事件 + _gui_input 处理，拖拽时创建半透明副本跟随鼠标
4. **精灵图切割**: 运行时用 AtlasTexture 动态创建，根据 spriteIdx 计算 region 位置，避免手动切图
5. **信号解耦**: GameManager 只管逻辑和状态，不直接操作 UI 节点，通过信号通知 UI 层刷新和播放动效
6. **CRT shader 性能**: shader 开销极低，用 uniform 控制强度，确保不影响帧率

## Skill

- **godot-dev**: Godot 游戏开发统一入口，负责环境检测、项目创建、场景和脚本生成。将使用此 skill 完成整个 Godot 项目的搭建、场景创建、脚本编写、音效集成和动效实现。
- Purpose: 创建 Godot 项目、生成所有场景和脚本文件、部署和测试
- Expected outcome: 完整可运行的卡牌 Roguelike Godot 项目