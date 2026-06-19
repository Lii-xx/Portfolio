extends RefCounted
## 盾反效果: 能力牌，打出后注册到 powers 列表
## 回合结束对随机敌人造成当前格挡一半的伤害（由 GameManager.end_turn 处理）
## 能力牌每关只能用一次（由 used_power_ids 控制），打出后不从手牌移除

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	game_state["player"]["powers"].append("shield_counter")
	return {
		"events": [{"type": "power", "power": "shield_counter"}],
		"meta": {},
	}
