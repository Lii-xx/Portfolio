extends Node
## MonsterRegistry - 怪物注册表，扫描data/monsters/目录加载所有怪物定义

var _monsters: Dictionary = {}  # id -> Dictionary

func _ready() -> void:
	_load_all_monsters()

func _load_all_monsters() -> void:
	_monsters = JsonLoader.load_all_json_in_dir("res://data/monsters")
	print("[MonsterRegistry] Loaded %d monsters" % _monsters.size())

func get_monster(id: String) -> Dictionary:
	if _monsters.has(id):
		return _monsters[id]
	push_error("[MonsterRegistry] Monster not found: " + id)
	return {}

func get_all_ids() -> Array:
	return _monsters.keys()

func make_monster(id: String) -> Dictionary:
	var def = get_monster(id)
	if def.is_empty():
		return {}
	return {
		"def_key": id,
		"name": def.get("name", "???"),
		"hp": def.get("hp", 1),
		"current_hp": def.get("hp", 1),
		"is_boss": def.get("is_boss", false),
		"sprite_idx": def.get("sprite_idx", 0),
		"intents": def.get("intents", []),
		"intent_idx": 0,
		"block": 0,
	}
