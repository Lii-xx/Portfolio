extends RefCounted
## 骰子效果: 掷骰子1-6，触发对应随机效果（对齐HTML）
## ①力量+1 ②每回合+2防御 ③随机敌人2连击 ④加4血下次攻击+6 ⑤随机敌人中毒5/回合 ⑥对全体敌人造成6×2伤害+6防御
## lucky_draw 能力牌影响概率：1-3权重×0.5^n，4-6权重×1.5^n（n=luckyCount，多张叠加）

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	# 骰子滚动音效
	EventBus.sfx_requested.emit("dice_roll")
	var roll = _roll_dice(game_state)
	var player = game_state["player"]
	var events: Array = []
	var strength = GameManager.get_strength()

	match roll:
		1: # 力量+1
			player["temp_strength"] = player.get("temp_strength", 0) + 1
			events.append({"type": "buff", "buff_type": "strength", "value": 1})
		2: # 每回合+2防御（骰子专属，每场战斗重置，对齐HTML diceBlockBuff）
			player["dice_block_buff"] = player.get("dice_block_buff", 0) + 2
			events.append({"type": "buff", "buff_type": "delayed_block", "value": 2})
		3: # 随机敌人2连击
			var alive = _alive_monsters_with_idx(game_state)
			if not alive.is_empty():
				var pick = alive[randi() % alive.size()]
				for _i in range(2):
					if pick.monster["current_hp"] <= 0:
						break
					var dmg = 4 + strength
					# 应用下次攻击加成（对齐HTML）
					if player.get("next_atk_bonus", 0) > 0:
						dmg += player["next_atk_bonus"]
						player["next_atk_bonus"] = 0
					var actual = DamageCalculator.apply_damage_to_monster(pick.monster, dmg)
					events.append({"type": "dmg", "idx": pick.idx, "value": actual, "to_player": false})
					if pick.monster["current_hp"] <= 0:
						events.append({"type": "kill", "idx": pick.idx})
					# 触发獠牙（对齐HTML）
					GameManager._apply_fangs_buff(actual, events)
		4: # 加4血下次攻击+6
			player["hp"] = mini(player["max_hp"], player["hp"] + 4)
			player["next_atk_bonus"] = player.get("next_atk_bonus", 0) + 6
			events.append({"type": "heal", "value": 4})
		5: # 随机敌人中毒5/回合（对齐HTML：中毒不衰减）
			var alive2 = _alive_monsters_with_idx(game_state)
			if not alive2.is_empty():
				var pick2 = alive2[randi() % alive2.size()]
				pick2.monster["poison"] = pick2.monster.get("poison", 0) + 5
				events.append({"type": "poison", "idx": pick2.idx, "value": 5})
		6: # 对全体敌人造成6×2伤害+6防御
			for i in range(game_state["monsters"].size()):
				var m = game_state["monsters"][i]
				if m["current_hp"] <= 0:
					continue
				for _j in range(2):
					if m["current_hp"] <= 0:
						break
					var dmg = 6 + strength
					# 应用下次攻击加成（对齐HTML）
					if player.get("next_atk_bonus", 0) > 0:
						dmg += player["next_atk_bonus"]
						player["next_atk_bonus"] = 0
					var actual = DamageCalculator.apply_damage_to_monster(m, dmg)
					events.append({"type": "dmg", "idx": i, "value": actual, "to_player": false})
					if m["current_hp"] <= 0:
						events.append({"type": "kill", "idx": i})
					# 触发獠牙（对齐HTML）
					GameManager._apply_fangs_buff(actual, events)
			player["block"] += 6
			player["card_block_this_turn"] = player.get("card_block_this_turn", 0) + 6
			events.append({"type": "block", "value": 6})

	events.append({"type": "dice", "value": roll})
	return {"events": events, "meta": {}}

## 掷骰子，lucky_draw 影响概率（对齐HTML加权抽样，多张叠加）
func _roll_dice(game_state: Dictionary) -> int:
	var lucky_count = game_state["player"].get("powers", []).filter(func(p): return p == "lucky_draw").size()
	if lucky_count > 0:
		# 加权抽样：1-3权重 0.5^n，4-6权重 1.5^n（n=luckyCount）
		var low_w = pow(0.5, lucky_count)
		var high_w = pow(1.5, lucky_count)
		var weights = [low_w, low_w, low_w, high_w, high_w, high_w]
		var total = 0.0
		for w in weights:
			total += w
		var rand_val = randf() * total
		var cum = 0.0
		for i in range(6):
			cum += weights[i]
			if rand_val <= cum:
				return i + 1
		return 6
	return randi() % 6 + 1

## 获取活着的怪物列表（带 idx）
func _alive_monsters_with_idx(game_state: Dictionary) -> Array:
	var result: Array = []
	for i in range(game_state["monsters"].size()):
		var m = game_state["monsters"][i]
		if m["current_hp"] > 0:
			result.append({"idx": i, "monster": m})
	return result
