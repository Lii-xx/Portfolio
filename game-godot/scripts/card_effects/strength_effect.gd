extends RefCounted
## 战意效果: 本场战斗临时+4力量
## 增益值集中在 BUFF 常量，方便调平衡

const BUFF: int = 4

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	game_state["player"]["temp_strength"] = game_state["player"].get("temp_strength", 0) + BUFF
	return {
		"events": [{"type": "buff", "buff_type": "strength", "value": BUFF}],
		"meta": {},
	}
