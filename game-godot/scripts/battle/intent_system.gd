extends Node
class_name IntentSystem
## 怪物意图循环管理

## 获取怪物当前意图
static func get_current_intent(monster: Dictionary) -> Dictionary:
	var intents = monster.get("intents", [])
	if intents.is_empty():
		return {"type": "attack", "value": 0, "debuff": null}
	var idx = monster.get("intent_idx", 0) % intents.size()
	return intents[idx]

## 推进怪物意图到下一个
static func advance_intent(monster: Dictionary) -> void:
	monster["intent_idx"] = monster.get("intent_idx", 0) + 1

## 获取意图显示文本（保留兼容，UI层优先用 get_intent_icon + get_intent_value_text）
static func get_intent_text(intent: Dictionary) -> String:
	match intent["type"]:
		"attack":
			return "攻 " + str(intent["value"])
		"defend":
			return "盾 " + str(intent["value"])
		"debuff":
			var label = "禁攻" if intent.get("debuff") == "no_attack" else "禁防"
			return "咒 " + label
		_:
			return "?"

## 获取意图图标名（对应 assets/icons/*.svg）
static func get_intent_icon(intent: Dictionary) -> String:
	match intent["type"]:
		"attack":
			return "attack"
		"defend":
			return "shield"
		"debuff":
			return "curse"
		_:
			return ""

## 获取意图数值文本（不含图标）
static func get_intent_value_text(intent: Dictionary) -> String:
	match intent["type"]:
		"attack":
			return str(intent["value"])
		"defend":
			return str(intent["value"])
		"debuff":
			return "禁攻" if intent.get("debuff") == "no_attack" else "禁防"
		_:
			return "?"

## 获取意图颜色名（用于UI）
static func get_intent_color_name(intent: Dictionary) -> String:
	match intent["type"]:
		"attack":
			return "atk"
		"defend":
			return "def"
		"debuff":
			return "debuff"
		_:
			return "default"
