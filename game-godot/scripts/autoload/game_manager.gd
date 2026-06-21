extends Node
## GameManager - 游戏状态管理单例
## 包含玩家数据、卡组、战斗状态、回合逻辑
## 回合/阶段状态统一用 state["phase"]（"battle"/"campfire"/"reward"/"sacrifice"）
## 与 state["animating"] 管理（无独立回合状态机）。

# === 平衡常量（方便统一调数值，避免魔法数字散落各处）===
const CAMPFIRE_STR_BONUS: int = 3  # 火堆"力量加持"激活时每场战斗 +的力量（对齐HTML）
const DEFAULT_MAX_ENERGY: int = 2  # 每回合默认最大能量
const MAX_EXTRA_ENERGY: int = 6    # 韬光养晦等效果累加的最大能量上限

var state: Dictionary = {}
var _state_snapshot: Dictionary = {}  # 关卡初始状态快照（用于SL读档）

func _ready() -> void:
	pass

func init_game() -> void:
	CardRegistry.reset_id_counter()
	state = {
		"player": {
			"hp": 60,
			"max_hp": 60,
			"block": 0,
			"energy": DEFAULT_MAX_ENERGY,       # 当前能量
			"max_energy": DEFAULT_MAX_ENERGY,   # 最大能量（可被 extra_plays 增加）
			"perm_strength": 0,
			"temp_strength": 0,
			"campfire_str_buff": 0,
			"debuffs": [],
			"deck": [],
			"played_count": 0,                  # 本回合已出牌数（仅统计用，不限制）
			"extra_plays": 0,                   # 本回合额外最大能量（由 next_extra_plays 转入）
			"next_extra_plays": 0,              # 下回合额外最大能量（韬光养晦等）
			"powers": [],                        # 已激活的能力牌（shield_counter/show_fangs 等）
			"used_power_ids": [],               # 本关已使用的能力牌 id（能力牌每关最多用一次）
			"next_atk_bonus": 0,                # 下次攻击额外伤害
			"dice_block_buff": 0,               # 每回合开始+X格挡（骰子效果）
			"thorn_buff": 0,                    # 荆棘反伤
			"delayed_block_buff": 0,            # 每回合开始+X格挡（延迟奖励）
			"card_block_this_turn": 0,          # 本回合卡牌提供的格挡
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

## 保存当前 state 的深拷贝作为关卡初始快照（用于SL读档）
func save_snapshot() -> void:
	_state_snapshot = state.duplicate(true)

## 读档：将快照深拷贝回 state，返回 true 表示成功
func load_snapshot() -> bool:
	if _state_snapshot.is_empty():
		push_warning("[GameManager] load_snapshot: 快照为空，无法读档")
		return false
	state = _state_snapshot.duplicate(true)
	state["animating"] = false
	state["selection"] = null
	return true

func get_strength() -> int:
	var p = state["player"]
	var camp_bonus = CAMPFIRE_STR_BONUS if p.get("campfire_str_buff", 0) > 0 else 0
	return p["perm_strength"] + p.get("temp_strength", 0) + camp_bonus

func can_play_card(card: Dictionary) -> bool:
	if state.get("phase") != "battle":
		return false
	# 注意：不检查 animating（对齐HTML canPlayCard）
	# animating 状态由 UI 层面控制（按钮禁用等），避免 confirm 时设置 animating 后 play_card 失败
	# 能量检查：spin 需要>=1能量，其他需要 cost<=energy
	var energy = state["player"].get("energy", 0)
	if card.get("special") == "spin":
		if energy < 1:
			return false
	else:
		if card.get("cost", 0) > energy:
			return false
	if card.get("special") == "blank":
		return false
	if card.get("uses_left", 0) <= 0 and card.get("max_uses", 0) > 0:
		return false
	# 能力牌每关最多使用一次
	if card.get("type") == "power" and state["player"]["used_power_ids"].has(card["id"]):
		return false
	# 虚弱/缴械等 debuff
	if card.get("type") == "attack" and card.get("special") != "dice" and state["player"]["debuffs"].has("no_attack"):
		return false
	if card.get("type") in ["utility", "defense", "power"] and card.get("special") != "dice" and state["player"]["debuffs"].has("no_defense"):
		return false
	return true

func is_sacrifice_eligible(card: Dictionary) -> bool:
	if card.get("special") == "blank":
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
##   - 通用流程：扣能量 / 扣耐久 / 造成伤害 / 加格挡
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

	# 出牌音效（T1：文件不存在时SoundManager静默跳过）
	EventBus.sfx_requested.emit("card_play")

	# 能量消耗：spin 消耗全部能量，其他消耗 cost
	var spin_energy := 0
	if card.get("special") == "spin":
		spin_energy = state["player"]["energy"]
		state["player"]["energy"] = 0
	else:
		state["player"]["energy"] -= card.get("cost", 0)

	# 能力牌标记本关已使用
	if card.get("type") == "power":
		state["player"]["used_power_ids"].append(card_id)

	# 消耗耐久（无耐久的牌不受影响），耐久用完自动移除（对齐HTML）
	if card.get("max_uses", 0) > 0:
		card["uses_left"] -= 1
		if card["uses_left"] <= 0:
			remove_self = true

	# 造成伤害（含 AOE）
	var total_damage_dealt := 0
	if card.get("damage", 0) > 0:
		var dmg: int
		if card.get("special") == "spin":
			# 旋斩：伤害 = (damage + 力量) × 消耗能量（每段伤害都吃力量加成）
			dmg = (card["damage"] + get_strength()) * spin_energy
		else:
			dmg = DamageCalculator.calc_card_damage(card, get_strength())
		# 下次攻击加成（骰子效果等）
		if state["player"].get("next_atk_bonus", 0) > 0:
			dmg += state["player"]["next_atk_bonus"]
			state["player"]["next_atk_bonus"] = 0
		if card.get("aoe", false):
			for i in range(state["monsters"].size()):
				var m = state["monsters"][i]
				if m["current_hp"] <= 0:
					continue
				var actual = DamageCalculator.apply_damage_to_monster(m, dmg)
				total_damage_dealt += actual
				events.append({"type": "dmg", "idx": i, "value": actual, "to_player": false})
				if m["current_hp"] <= 0:
					events.append({"type": "kill", "idx": i})
				# 露出獠牙（被动）：每次造成伤害获得力量
				_apply_fangs_buff(actual, events)
		else:
			var actual = DamageCalculator.apply_damage_to_monster(target, dmg)
			total_damage_dealt = actual
			events.append({"type": "dmg", "idx": target_idx, "value": actual, "to_player": false})
			if target["current_hp"] <= 0:
				events.append({"type": "kill", "idx": target_idx})
			# 露出獠牙（被动）
			_apply_fangs_buff(actual, events)

	# 格挡
	if card.get("block", 0) > 0:
		state["player"]["block"] += card["block"]
		state["player"]["card_block_this_turn"] += card["block"]
		events.append({"type": "block", "value": card["block"]})

	# 将伤害信息存入 state，供效果脚本使用（模块化：效果脚本不依赖 special 分支）
	state["_last_damage_dealt"] = total_damage_dealt
	state["_last_target_idx"] = target_idx
	state["_spin_energy"] = spin_energy

	# 特殊效果（统一入口，不认识具体效果名）
	var special = card.get("special")
	if special and special != "" and EffectRegistry.has_effect(special):
		var result = EffectRegistry.execute_effect(special, card, target_idx, state)
		events.append_array(result["events"])
		var meta = result.get("meta", {})
		if meta.get("remove_self", false):
			remove_self = true
		# 追加攻击（如连劈后续击）：效果已自行结算伤害，这里补发 dmg/kill 事件用于 UI 与死亡判定
		for atk in meta.get("extra_attacks", []):
			var a_idx: int = atk["idx"]
			if a_idx >= 0 and a_idx < state["monsters"].size():
				var m2 = state["monsters"][a_idx]
				events.append({"type": "dmg", "idx": a_idx, "value": atk["value"], "to_player": false})
				if m2["current_hp"] <= 0:
					events.append({"type": "kill", "idx": a_idx})
				# 追加攻击也触发獠牙
				_apply_fangs_buff(atk["value"], events)

	# 清理临时状态
	state.erase("_last_damage_dealt")
	state.erase("_last_target_idx")
	state.erase("_spin_energy")

	if remove_self:
		_remove_card(card_id)

	return events

## 露出獠牙（被动效果）：每次造成伤害获得力量
## show_fangs 能力牌打出后注册到 powers，这里统一触发
func _apply_fangs_buff(actual_damage: int, events: Array) -> void:
	if actual_damage <= 0:
		return
	var fangs = state["player"]["powers"].filter(func(p): return p == "show_fangs").size()
	if fangs > 0:
		state["player"]["temp_strength"] += fangs
		events.append({"type": "fangs_buff", "value": fangs})

## 怪物行动，返回事件列表
func monster_turn() -> Array:
	state["player"]["debuffs"] = []
	var events: Array = []

	# 1. 怪物中毒伤害（回合开始时结算，对齐HTML：中毒不衰减，永久持续）
	for i in range(state["monsters"].size()):
		var m = state["monsters"][i]
		if m["current_hp"] <= 0:
			continue
		var poison = m.get("poison", 0)
		if poison > 0:
			var actual = DamageCalculator.apply_damage_to_monster(m, poison)
			events.append({"type": "poison_dmg", "idx": i, "value": actual, "to_player": false})
			if m["current_hp"] <= 0:
				events.append({"type": "kill", "idx": i})

	# 2. 怪物行动
	for i in range(state["monsters"].size()):
		var m = state["monsters"][i]
		if m["current_hp"] <= 0:
			continue
		var intent = IntentSystem.get_current_intent(m)
		match intent["type"]:
			"attack":
				var result = DamageCalculator.apply_damage_to_player(state["player"], intent["value"])
				var actual_dmg = result.get("damage", 0)
				events.append({"type": "monster_atk", "value": intent["value"], "blocked": result["blocked"], "actual_dmg": actual_dmg, "idx": i})
				# 荆棘护甲反伤（怪物攻击玩家即触发，对齐HTML）
				var thorn = state["player"].get("thorn_buff", 0)
				if thorn > 0:
					var thorn_actual = DamageCalculator.apply_damage_to_monster(m, thorn)
					events.append({"type": "thorn_dmg", "idx": i, "value": thorn_actual, "to_player": false})
					if m["current_hp"] <= 0:
						events.append({"type": "kill", "idx": i})
					# 荆棘反伤触发獠牙（对齐HTML）
					_apply_fangs_buff(thorn_actual, events)
			"defend":
				m["block"] += intent["value"]
				events.append({"type": "monster_def", "monster_name": m["name"], "value": intent["value"]})
			"debuff":
				if intent.get("debuff") and not state["player"]["debuffs"].has(intent["debuff"]):
					state["player"]["debuffs"].append(intent["debuff"])
					events.append({"type": "debuff", "debuff": intent["debuff"]})
		IntentSystem.advance_intent(m)

	return events

## 结束回合（玩家回合结束 → 进入怪物回合）
## 恢复下回合能量、处理 extra_plays、重置 played_count、清怪物格挡
## 返回盾反事件列表（阶段1暂未实现盾反，返回空数组）
func end_turn() -> Array:
	var p = state["player"]
	var shield_events: Array = []
	# 盾反：回合结束对随机敌人造成当前格挡一半的伤害（多张叠加）
	var shield_count = p.get("powers", []).filter(func(x): return x == "shield_counter").size()
	if shield_count > 0 and p.get("block", 0) > 0:
		var counter_dmg = ceili(p["block"] / 2.0 * shield_count)
		if counter_dmg > 0:
			var alive = alive_monsters()
			if not alive.is_empty():
				var target = alive[randi() % alive.size()]
				var actual = DamageCalculator.apply_damage_to_monster(target, counter_dmg)
				shield_events.append({"type": "dmg", "idx": state["monsters"].find(target), "value": actual, "to_player": false})
				if target["current_hp"] <= 0:
					shield_events.append({"type": "kill", "idx": state["monsters"].find(target)})
				# 盾反触发獠牙（对齐HTML）
				_apply_fangs_buff(actual, shield_events)
	# 恢复下回合能量：extra_plays 转入 max_energy，energy 恢复满
	p["extra_plays"] = p.get("next_extra_plays", 0)
	p["max_energy"] = DEFAULT_MAX_ENERGY + p["extra_plays"]
	p["energy"] = p["max_energy"]
	p["next_extra_plays"] = 0
	p["played_count"] = 0
	# 怪物格挡每回合清零（与玩家一致），否则防御意图会无限累加护甲导致后期几乎打不动
	for m in state.get("monsters", []):
		m["block"] = 0
	state["selection"] = null
	return shield_events

## 开始回合（怪物回合结束 → 进入玩家回合）
## 清玩家格挡、应用延迟奖励/骰子防御加成
func start_turn() -> void:
	var p = state["player"]
	p["block"] = 0
	p["card_block_this_turn"] = 0
	# 骰子效果：每回合开始+X格挡
	if p.get("dice_block_buff", 0) > 0:
		p["block"] += p["dice_block_buff"]
	# 延迟奖励：每回合开始+X格挡
	if p.get("delayed_block_buff", 0) > 0:
		p["block"] += p["delayed_block_buff"]

## 进入下一层
func advance_floor() -> String:
	state["combat_count"] += 1
	var campfire_floors = EncounterRegistry.get_campfire_floors()
	# JSON解析后元素是float，转成int确保与combat_count(int)类型匹配
	var cf_int: Array = []
	for f in campfire_floors:
		cf_int.append(int(f))
	print("[GameManager] advance_floor: combat_count=%d, campfire_floors=%s" % [state["combat_count"], cf_int])
	if cf_int.has(state["combat_count"]):
		state["floor"] += 1
		state["phase"] = "campfire"
		print("[GameManager] advance_floor: returning 'campfire', phase=%s" % state["phase"])
		return "campfire"
	state["floor"] += 1
	var result = spawn_encounter()
	# victory 时没有下一层，回退 floor+1，保持最高通关楼层=最后一层
	if result == "victory":
		state["floor"] -= 1
	print("[GameManager] advance_floor: returning '%s'" % result)
	return result

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
	state["player"]["card_block_this_turn"] = 0
	state["player"]["temp_strength"] = 0
	state["player"]["debuffs"] = []
	state["player"]["energy"] = DEFAULT_MAX_ENERGY
	state["player"]["max_energy"] = DEFAULT_MAX_ENERGY
	state["player"]["played_count"] = 0
	state["player"]["extra_plays"] = 0
	state["player"]["next_extra_plays"] = 0
	state["player"]["powers"] = []
	state["player"]["used_power_ids"] = []
	state["player"]["next_atk_bonus"] = 0
	state["player"]["dice_block_buff"] = 0
	state["player"]["thorn_buff"] = 0
	state["player"]["delayed_block_buff"] = state["player"].get("delayed_block_buff", 0)  # 延迟奖励跨战斗保留
	state["phase"] = "battle"
	state["selection"] = null
	# 保存关卡初始快照（用于SL读档）
	save_snapshot()
	return "battle"

## 火堆选择
func campfire_choice(choice_id: String) -> String:
	var choices = JsonLoader.load_json("res://data/campfire.json").get("choices", [])
	for choice in choices:
		if choice["id"] == choice_id:
			_apply_campfire_choice(choice)
			break
	state["floor"] += 1  # 火堆层已算一层，离开火堆进入下一层再+1
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
	state["player"]["perm_strength"] = state["player"].get("perm_strength", 0) + 1
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
