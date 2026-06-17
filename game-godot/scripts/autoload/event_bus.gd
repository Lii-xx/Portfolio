extends Node
## EventBus - 全局信号总线，逻辑层与表现层解耦

# 战斗事件
signal card_played(card_id: int, target_idx: int, events: Array)
signal card_selected(card_id: int, target_idx: int)
signal card_selection_cleared
signal confirm_play_requested
signal turn_skipped

signal monster_damaged(monster_idx: int, damage: int)
signal monster_killed(monster_idx: int)
signal monster_blocked(monster_name: String, value: int)

signal player_damaged(damage: int, blocked: int)
signal player_healed(amount: int)
signal player_block_gained(amount: int)
signal buff_applied(buff_type: String, value: int)
signal debuff_applied(debuff_type: String)

signal combat_won
signal combat_lost(floor: int)
signal victory

# 回合事件
signal turn_started
signal turn_ended
signal phase_changed(phase: String)

# 元游戏事件
signal campfire_entered
signal campfire_choice_made(choice_id: String)
signal reward_shown(is_sacrifice: bool, is_blank: bool)
signal reward_picked(card_key: String, is_sacrifice: bool, is_blank: bool)
signal delayed_reward_picked(reward_id: String)
signal sacrifice_entered
signal sacrifice_completed(card_ids: Array)
signal blank_convert_requested

# 屏幕切换
signal screen_requested(screen_name: String)
signal game_started
signal game_restart_requested
signal title_requested

# 音效事件
signal sfx_requested(sfx_name: String)
signal bgm_requested(bgm_name: String)
signal bgm_stopped
