extends RefCounted
## 露出獠牙效果: 能力牌，打出后注册到 powers 列表
## 每次造成伤害获得1点力量（由 GameManager._apply_fangs_buff 统一触发）
## 能力牌每关只能用一次（由 used_power_ids 控制），打出后不从手牌移除

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	game_state["player"]["powers"].append("show_fangs")
	return {
		"events": [{"type": "power", "power": "show_fangs"}],
		"meta": {},
	}
