extends RefCounted
## 战意效果: 本场战斗临时+3力量（对齐HTML）
## 增益值集中在 BUFF 常量，方便调平衡

const BUFF: int = 3

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	# 增益音效
	EventBus.sfx_requested.emit("buff")
	game_state["player"]["temp_strength"] = game_state["player"].get("temp_strength", 0) + BUFF
	return {
		"events": [{"type": "buff", "buff_type": "strength", "value": BUFF}],
		"meta": {},
	}
