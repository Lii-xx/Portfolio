extends RefCounted
## 吸血效果: 回复 HEAL 点生命（不超过上限）
## 增益值集中在 HEAL 常量，方便调平衡

const HEAL: int = 3

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	var player = game_state["player"]
	player["hp"] = mini(player["max_hp"], player["hp"] + HEAL)
	return {
		"events": [{"type": "heal", "value": HEAL}],
		"meta": {},
	}
