extends Node
## GameManager - 游戏状态管理单例
## 包含玩家数据、卡组、战斗状态、回合逻辑
## 回合/阶段状态统一用 state["phase"]（"battle"/"campfire"/"reward"/"sacrifice"）
## 与 state["animating"] 管理（无独立回合状态机）。

# === 平衡常量（方便统一调数值，避免魔法数字散落各处）===
const CAMPFIRE_STR_BONUS: int = 5  # 火堆"力量加持"激活时每场战斗 +的力量

var state: Dictionary = {}

func _ready() -> void:
	pass

func init_game() -> void:
	CardRegistry.reset_id_counter()
	state = {
		"player": {
			"hp": 60,
			"max_hp": 60,
			"block": 0,
			"perm_strength": 0,
			"temp_strength": 0,
			"campfire_str_buff": 0,
			"debuffs": [],
			"deck": [],
			"played_count": 0,
			"extra_plays": 0,
			"next_extra_plays": 0,
			"powers": [],
		},
		"floor": 1,
		"combat_count": 0,
		"monsters": [],
		"is_group": false,
		"phase": "battle",
		"selection": null,
		"sacrifice_selected": [],
		"blank_convert_count": 0,
		"animating": false,
	}
	# 构建初始卡组
	var starting = EncounterRegistry.get_starting_deck()
	state["player"]["deck"] = []
	for card_key in starting:
		state["player"]["deck"].append(CardRegistry.make_card(card_key))

func get_strength() -> int:
	var p = state["player"]
	var camp_bonus = CAMPFIRE_STR_BONUS if p.get("campfire_str_buff", 0) > 0 else 0
	return p["perm_strength"] + p.get("temp_strength", 0) + camp_bonus

func can_play_card(card: Dictionary) -> bool:
	if state.get("phase") != "battle":
		return false
	if state.get("animating", false):
		return false
	var max_plays = 1 + state["player"].get("extra_plays", 0)
	if state["player"]["played_count"] >= max_plays:
		return false
	if card.get("special") == "blank":
		return false
	if card.get("uses_left", 0) <= 0 and card.get("max_uses", 0) > 0:
		return false
	if card.get("type") == "attack" and state["player"]["debuffs"].has("no_attack"):
		return false
	var card_type = card.get("type", "")
	if (card_type in ["utility", "defense", "power"]) and state["player"]["debuffs"].has("no_defense"):
		return false
	return true

func is_sacrifice_eligible(card: Dictionary) -> bool:
	if card.get("special") in ["blank", "instant_kill"]:
		return false
	return card.get("uses_left", 0) >= 3

func alive_monsters() -> Array:
	var result = []
	for m in state.get("monsters", []):
		if m["current_hp"] > 0:
			result.append(m)
	return result

func check_combat_win() -> bool:
	return alive_monsters().is_empty()

## 出牌逻辑，返回事件列表。
## 本函数对具体 special 名称保持无知（开闭原则）：
##   - 通用流程：扣耐久 / 造成伤害 / 加格挡
##   - 特殊效果：全部交给 EffectRegistry，效果通过返回的 meta 声明副作用
##     (remove_self / extra_attacks)，由这里统一执行。
## 新增/修改机制卡时，只需写/改对应的 *_effect.gd，无需改动本函数。
func play_card(card_id: int, target_idx: int) -> Array:
	var card = _find_card(card_id)
	if card.is_empty() or not can_play_card(card):
		return []
	var target = state["monsters"][target_idx] if target_idx < state["monsters"].size() else null
	if target == null or target["current_hp"] <= 0:
		return []

	state["player"]["played_count"] += 1
	var events: Array = []
	var remove_self := false

	# 消耗耐久（无耐久的牌不受影响）
	if card.get("max_uses", 0) > 0:
		card["uses_left"] -= 1

	# 造成伤害（含 AOE）
	if card.get("damage", 0) > 0:
		var dmg = DamageCalculator.calc_card_damage(card, get_strength())
		if card.get("aoe", false):
			for i in range(state["monsters"].size()):
				var m = state["monsters"][i]
				if m["current_hp"] <= 0:
					continue
				var actual = DamageCalculator.apply_damage_to_monster(m, dmg)
				events.append({"type": "dmg", "idx": i, "value": actual, "to_player": false})
				if m["current_hp"] <= 0:
					events.append({"type": "kill", "idx": i})
		else:
			var actual = DamageCalculator.apply_damage_to_monster(target, dmg)
			events.append({"type": "dmg", "idx": target_idx, "value": actual, "to_player": false})
			if target["current_hp"] <= 0:
				events.append({"type": "kill", "idx": target_idx})

	# 格挡
	if card.get("block", 0) > 0:
		state["player"]["block"] += card["block"]
		events.append({"type": "block", "value": card["block"]})

	# 特殊效果（统一入口，不认识具体效果名）
	var special = card.get("special")
	if special and special != "" and EffectRegistry.has_effect(special):
		var result = EffectRegistry.execute_effect(special, card, target_idx, state)
		events.append_array(result["events"])
		var meta = result.get("meta", {})
		if meta.get("remove_self", false):
			remove_self = true
		# 追加攻击（如连劈第二击）：效果已自行结算伤害，这里补发 dmg/kill 事件用于 UI 与死亡判定
		for atk in meta.get("extra_attacks", []):
			var a_idx: int = atk["idx"]
			if a_idx >= 0 and a_idx < state["monsters"].size():
				var m2 = state["monsters"][a_idx]
				events.append({"type": "dmg", "idx": a_idx, "value": atk["value"], "to_player": false})
				if m2["current_hp"] <= 0:
					events.append({"type": "kill", "idx": a_idx})

	if remove_self:
		_remove_card(card_id)

	return events

## 怪物行动，返回事件列表
func monster_turn() -> Array:
	state["player"]["debuffs"] = []
	var events: Array = []

	for m in state["monsters"]:
		if m["current_hp"] <= 0:
			continue
		var intent = IntentSystem.get_current_intent(m)
		match intent["type"]:
			"attack":
				var result = DamageCalculator.apply_damage_to_player(state["player"], intent["value"])
				events.append({"type": "monster_atk", "value": intent["value"], "blocked": result["blocked"]})
			"defend":
				m["block"] += intent["value"]
				events.append({"type": "monster_def", "monster_name": m["name"], "value": intent["value"]})
			"debuff":
				if intent.get("debuff") and not state["player"]["debuffs"].has(intent["debuff"]):
					state["player"]["debuffs"].append(intent["debuff"])
					events.append({"type": "debuff", "debuff": intent["debuff"]})
		IntentSystem.advance_intent(m)

	return events

## 结束回合
func end_turn() -> void:
	var p = state["player"]
	# 处理能力牌效果
	for power in p.get("powers", []):
		if power == "eternal_strength":
			p["perm_strength"] += 1
	p["block"] = 0
	p["played_count"] = 0
	p["extra_plays"] = p.get("next_extra_plays", 0)
	p["next_extra_plays"] = 0
	# 怪物格挡每回合清零（与玩家一致），否则防御意图会无限累加护甲导致后期几乎打不动
	for m in state.get("monsters", []):
		m["block"] = 0
	state["selection"] = null

## 进入下一层
func advance_floor() -> String:
	state["combat_count"] += 1
	if EncounterRegistry.get_campfire_floors().has(state["combat_count"]):
		state["floor"] += 1
		state["phase"] = "campfire"
		return "campfire"
	state["floor"] += 1
	return spawn_encounter()

## 生成战斗
func spawn_encounter() -> String:
	var encounter = EncounterRegistry.get_encounter(state["combat_count"])
	if encounter.is_empty():
		return "victory"

	state["monsters"] = []
	state["is_group"] = encounter.get("is_group", false)

	var monster_list = encounter.get("monsters", [])
	for monster_id in monster_list:
		state["monsters"].append(MonsterRegistry.make_monster(monster_id))

	# 重置战斗相关状态
	state["player"]["block"] = 0
	state["player"]["temp_strength"] = 0
	state["player"]["debuffs"] = []
	state["player"]["played_count"] = 0
	state["player"]["extra_plays"] = 0
	state["player"]["next_extra_plays"] = 0
	state["player"]["powers"] = []
	state["phase"] = "battle"
	state["selection"] = null
	return "battle"

## 火堆选择
func campfire_choice(choice_id: String) -> String:
	var choices = JsonLoader.load_json("res://data/campfire.json").get("choices", [])
	for choice in choices:
		if choice["id"] == choice_id:
			_apply_campfire_choice(choice)
			break
	return spawn_encounter()

func _apply_campfire_choice(choice: Dictionary) -> void:
	match choice["type"]:
		"heal":
			state["player"]["hp"] = mini(state["player"]["max_hp"], state["player"]["hp"] + choice["value"])
		"campfire_str":
			state["player"]["campfire_str_buff"] = choice["value"]

## 献祭
func perform_sacrifice(ids: Array) -> void:
	for id in ids:
		_remove_card(id)
	state["sacrifice_selected"] = []
	state["phase"] = "battle"

## 空白牌兑换
func perform_blank_convert() -> bool:
	var blanks = []
	for card in state["player"]["deck"]:
		if card.get("special") == "blank":
			blanks.append(card)
	if blanks.size() < 2:
		return false
	_remove_card(blanks[0]["id"])
	_remove_card(blanks[1]["id"])
	return true

## 随机奖励卡牌
func random_rewards(count: int) -> Array:
	var reward_data = JsonLoader.load_json("res://data/rewards.json")
	var specials: Array = reward_data.get("special_cards", [])
	var normals: Array = reward_data.get("normal_cards", [])
	var special_prob: float = reward_data.get("special_prob", 0.1)

	var pool: Array = []
	var special_total = special_prob * specials.size()
	var normal_prob = (1.0 - special_total) / max(normals.size(), 1)
	for key in normals:
		pool.append({"key": key, "prob": normal_prob})
	for key in specials:
		pool.append({"key": key, "prob": special_prob})

	var results: Array = []
	var used: Dictionary = {}
	var safety = 0
	while results.size() < count and safety < 200:
		safety += 1
		var rand_val = randf()
		var cum_prob = 0.0
		for item in pool:
			cum_prob += item["prob"]
			if rand_val <= cum_prob and not used.has(item["key"]):
				used[item["key"]] = true
				var card_def = CardRegistry.get_card(item["key"])
				results.append({"key": item["key"], "data": card_def})
				break
	return results

## 延迟奖励
func get_delayed_rewards() -> Array:
	return JsonLoader.load_json("res://data/delayed_rewards.json").get("rewards", [])

func apply_delayed_reward(reward_id: String) -> void:
	for reward in get_delayed_rewards():
		if reward["id"] == reward_id:
			match reward["type"]:
				"max_hp":
					state["player"]["max_hp"] += reward["value"]
					state["player"]["hp"] += reward["value"]
				"perm_strength":
					state["player"]["perm_strength"] += reward["value"]
			break

## 开始游戏
func start_game() -> void:
	init_game()
	var result = spawn_encounter()
	print("[GameManager] start_game done, encounter result: %s, monsters: %d, deck: %d" % [result, state.get("monsters", []).size(), state["player"]["deck"].size()])

## 存取高分
func save_high_score() -> void:
	var hs = get_high_score()
	if state["floor"] > hs:
		var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
		if file:
			var data = {"high_score": state["floor"]}
			file.store_string(JSON.stringify(data))
			file.close()

func get_high_score() -> int:
	if not FileAccess.file_exists("user://save_data.json"):
		return 0
	var file = FileAccess.open("user://save_data.json", FileAccess.READ)
	if file == null:
		return 0
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) != OK:
		return 0
	return json.get_data().get("high_score", 0)

## 工具函数
func _find_card(card_id: int) -> Dictionary:
	for card in state["player"]["deck"]:
		if card["id"] == card_id:
			return card
	return {}

func _remove_card(card_id: int) -> void:
	state["player"]["deck"] = state["player"]["deck"].filter(func(c): return c["id"] != card_id)
