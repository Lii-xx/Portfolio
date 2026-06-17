extends Node
## EncounterRegistry - 关卡注册表，加载encounters.json

var _data: Dictionary = {}

func _ready() -> void:
	_data = JsonLoader.load_json("res://data/encounters.json")
	print("[EncounterRegistry] Loaded %d encounters" % get_total_encounters())

func get_encounter(index: int) -> Dictionary:
	var encounters = _data.get("encounters", [])
	if index < 0 or index >= encounters.size():
		return {}
	return encounters[index]

func get_total_encounters() -> int:
	return _data.get("encounters", []).size()

func get_campfire_floors() -> Array:
	return _data.get("campfire_after", [])

func get_starting_deck() -> Array:
	return _data.get("starting_deck", [])

func has_encounter(index: int) -> bool:
	return index >= 0 and index < get_total_encounters()
