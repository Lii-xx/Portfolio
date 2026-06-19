extends RefCounted
## 韬光养晦效果: 下回合最大能量+2（最多累计 MAX_EXTRA_ENERGY 张）
## 上限集中在常量，方便调平衡（对齐HTML：replay → nextExtraPlays+2，上限6）

const MAX_EXTRA_ENERGY: int = 6
const ENERGY_PER_PLAY: int = 2

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	var current = game_state["player"].get("next_extra_plays", 0)
	game_state["player"]["next_extra_plays"] = mini(current + ENERGY_PER_PLAY, MAX_EXTRA_ENERGY)
	return {
		"events": [{"type": "buff", "buff_type": "replay", "value": ENERGY_PER_PLAY}],
		"meta": {},
	}
