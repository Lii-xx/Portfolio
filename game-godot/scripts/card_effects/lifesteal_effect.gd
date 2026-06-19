extends RefCounted
## 吸血效果: 回复造成伤害的一半生命（对齐HTML）
## 从 game_state["_last_damage_dealt"] 读取本卡造成的伤害

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	var damage_dealt: int = game_state.get("_last_damage_dealt", 0)
	if damage_dealt <= 0:
		return {"events": [], "meta": {}}
	var player = game_state["player"]
	var heal = ceili(damage_dealt / 2.0)
	player["hp"] = mini(player["max_hp"], player["hp"] + heal)
	return {
		"events": [{"type": "heal", "value": heal}],
		"meta": {},
	}
