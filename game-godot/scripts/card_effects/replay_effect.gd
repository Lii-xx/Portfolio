extends RefCounted
## 重放效果: 下回合可多出1张牌（最多累计 MAX_EXTRA_PLAY 张）
## 上限集中在常量，方便调平衡

const MAX_EXTRA_PLAY: int = 4

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	var current = game_state["player"].get("next_extra_plays", 0)
	game_state["player"]["next_extra_plays"] = mini(current + 1, MAX_EXTRA_PLAY)
	return {
		"events": [{"type": "buff", "buff_type": "replay", "value": 1}],
		"meta": {},
	}
