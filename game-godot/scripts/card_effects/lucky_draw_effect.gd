extends RefCounted
## 吸欧气效果: 能力牌，打出后注册到 powers 列表
## 骰子1-3概率降低50%，4-6概率增加50%（影响 dice/fate_wheel 效果）
## 能力牌每关只能用一次（由 used_power_ids 控制），打出后不从手牌移除

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	game_state["player"]["powers"].append("lucky_draw")
	return {
		"events": [{"type": "power", "power": "lucky_draw"}],
		"meta": {},
	}
