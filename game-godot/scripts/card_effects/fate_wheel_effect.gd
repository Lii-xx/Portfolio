extends RefCounted
## 命运轮盘效果: 掷骰1-6，奇数对随机敌人造成3×点数伤害；偶数获得点数×2格挡（对齐HTML）
## 不受 lucky_draw 影响
## 奇数伤害不吃力量（纯骰点决定），偶数格挡计入 card_block_this_turn

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	var roll = randi() % 6 + 1
	var player = game_state["player"]
	var events: Array = [{"type": "dice", "value": roll}]

	if roll % 2 == 1:
		# 奇数：对随机敌人造成3×点数伤害（不吃力量，对齐HTML）
		var alive = _alive_monsters_with_idx(game_state)
		if not alive.is_empty():
			var pick = alive[randi() % alive.size()]
			var dmg = 3 * roll
			var actual = DamageCalculator.apply_damage_to_monster(pick.monster, dmg)
			events.append({"type": "dmg", "idx": pick.idx, "value": actual, "to_player": false})
			if pick.monster["current_hp"] <= 0:
				events.append({"type": "kill", "idx": pick.idx})
			# 触发獠牙（对齐HTML）
			GameManager._apply_fangs_buff(actual, events)
	else:
		# 偶数：获得点数×2格挡
		var block = roll * 2
		player["block"] += block
		player["card_block_this_turn"] = player.get("card_block_this_turn", 0) + block
		events.append({"type": "block", "value": block})

	return {"events": events, "meta": {}}

func _alive_monsters_with_idx(game_state: Dictionary) -> Array:
	var result: Array = []
	for i in range(game_state["monsters"].size()):
		var m = game_state["monsters"][i]
		if m["current_hp"] > 0:
			result.append({"idx": i, "monster": m})
	return result
