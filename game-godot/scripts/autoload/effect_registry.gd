extends Node
## EffectRegistry - 卡牌效果注册表，策略模式
## 将 special 名称映射到对应的效果脚本类
## 新增卡牌效果时：1.写 xxx_effect.gd  2.在此 register()  3.play_card 自动调用

var _effects: Dictionary = {}  # special_name -> GDScript

func _ready() -> void:
	_register_builtin_effects()

func _register_builtin_effects() -> void:
	# 攻击类效果
	register("strength", load("res://scripts/card_effects/strength_effect.gd"))
	register("lifesteal", load("res://scripts/card_effects/lifesteal_effect.gd"))
	register("triple_hit", load("res://scripts/card_effects/triple_hit_effect.gd"))
	register("bloodthirst", load("res://scripts/card_effects/bloodthirst_effect.gd"))
	register("spin", load("res://scripts/card_effects/spin_effect.gd"))
	# 防御/辅助类效果
	register("replay", load("res://scripts/card_effects/replay_effect.gd"))
	register("poison_spread", load("res://scripts/card_effects/poison_spread_effect.gd"))
	register("thorn_armor", load("res://scripts/card_effects/thorn_armor_effect.gd"))
	register("dice", load("res://scripts/card_effects/dice_effect.gd"))
	register("fate_wheel", load("res://scripts/card_effects/fate_wheel_effect.gd"))
	# 能力牌效果（打出后持续生效）
	register("shield_counter", load("res://scripts/card_effects/shield_counter_effect.gd"))
	register("show_fangs", load("res://scripts/card_effects/show_fangs_effect.gd"))
	register("lucky_draw", load("res://scripts/card_effects/lucky_draw_effect.gd"))
	# 无效果（由GameManager特殊处理）
	register("blank", null)
	print("[EffectRegistry] Registered %d effects" % _effects.size())

func register(special_name: String, effect_script: GDScript) -> void:
	_effects[special_name] = effect_script

func has_effect(special_name: String) -> bool:
	return _effects.has(special_name) and _effects[special_name] != null

## 执行效果。
## 返回 Dictionary: { "events": Array, "meta": Dictionary }
##   - events:  供 UI 播放的事件流（伤害/治疗/格挡/击杀...）
##   - meta:    效果对卡牌自身的声明，目前支持：
##       remove_self(bool)     打出后从卡组移除（如能力牌）
##       extra_attacks(Array)  需要对目标追加的伤害事件 [{idx, value}, ...]（如连劈后续击）
## 若效果不存在或返回旧式 Array，自动归一化为上述结构，调用方无需关心。
func execute_effect(special_name: String, source: Dictionary, target_idx: int, game_state: Dictionary) -> Dictionary:
	if not has_effect(special_name):
		return {"events": [], "meta": {}}
	var effect_script: GDScript = _effects[special_name]
	var effect_instance = effect_script.new()
	var result = effect_instance.execute(source, target_idx, game_state)
	if effect_instance is Node:
		effect_instance.queue_free()
	# 兼容旧式返回（纯 Array）与新式返回（Dictionary）
	if result is Array:
		return {"events": result, "meta": {}}
	if result is Dictionary:
		return {"events": result.get("events", []), "meta": result.get("meta", {})}
	return {"events": [], "meta": {}}
