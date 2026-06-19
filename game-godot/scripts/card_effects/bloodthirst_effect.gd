extends RefCounted
## 渴血效果: 造成10伤害，力量≥5时回复实际造成的伤害（对齐HTML）
## 从 game_state["_last_damage_dealt"] 读取本卡造成的伤害

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	var damage_dealt: int = game_state.get("_last_damage_dealt", 0)
	if damage_dealt <= 0:
		return {"events": [], "meta": {}}
	# 力量≥5时回复实际伤害
	if GameManager.get_strength() < 5:
		return {"events": [], "meta": {}}
	var player = game_state["player"]
	player["hp"] = mini(player["max_hp"], player["hp"] + damage_dealt)
	return {
		"events": [{"type": "heal", "value": damage_dealt}],
		"meta": {},
	}
