extends RefCounted
## 荆棘护甲效果: 获得4格挡（格挡由play_card通用流程处理），本关受击反伤4（可叠加）
## thorn_buff 由 monster_turn 在玩家受击时触发反伤

const THORN_AMOUNT: int = 4

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	game_state["player"]["thorn_buff"] = game_state["player"].get("thorn_buff", 0) + THORN_AMOUNT
	return {
		"events": [{"type": "buff", "buff_type": "thorn", "value": THORN_AMOUNT}],
		"meta": {},
	}
