extends RefCounted
## 永恒强化效果: 获得一个永久能力——每回合结束 +1 力量。
## 打出后从卡组移除（通过 meta.remove_self 声明，不再由 GameManager 硬编码处理）。

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	var powers = game_state["player"].get("powers", [])
	powers.append("eternal_strength")
	game_state["player"]["powers"] = powers
	return {
		"events": [{"type": "buff", "buff_type": "eternal_strength", "value": 3}],
		"meta": {"remove_self": true},
	}
