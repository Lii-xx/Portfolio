extends Node
## CardRegistry - 卡牌注册表，扫描data/cards/目录加载所有卡牌定义

var _cards: Dictionary = {}  # id -> Dictionary

func _ready() -> void:
	_load_all_cards()

func _load_all_cards() -> void:
	_cards = JsonLoader.load_all_json_in_dir("res://data/cards")
	print("[CardRegistry] Loaded %d cards" % _cards.size())

func get_card(id: String) -> Dictionary:
	if _cards.has(id):
		return _cards[id]
	push_error("[CardRegistry] Card not found: " + id)
	return {}

func get_all_ids() -> Array:
	return _cards.keys()

func make_card(id: String) -> Dictionary:
	var def = get_card(id)
	if def.is_empty():
		return {}
	return {
		"id": _next_card_id(),
		"def_key": id,
		"name": def.get("name", "???"),
		"type": def.get("type", "attack"),
		"cost": def.get("cost", 0),
		"damage": def.get("damage", 0),
		"block": def.get("block", 0),
		"max_uses": def.get("max_uses", 0),
		"uses_left": def.get("max_uses", 0),
		"desc": def.get("desc", ""),
		"special": def.get("special"),
		"aoe": def.get("aoe", false),
		"art": def.get("art", ""),
	}

var _card_id_counter: int = 0
func _next_card_id() -> int:
	_card_id_counter += 1
	return _card_id_counter

func reset_id_counter() -> void:
	_card_id_counter = 0
