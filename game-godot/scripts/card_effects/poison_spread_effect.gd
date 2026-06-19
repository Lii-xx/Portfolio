extends RefCounted
## 播毒效果: 对所有敌人造成3/回合的中毒效果（对齐HTML）
## 怪物每回合开始时受到 poison 伤害，然后 poison-1（由 monster_turn 处理）

const POISON_AMOUNT: int = 3

func execute(_source: Dictionary, _target_idx: int, game_state: Dictionary) -> Dictionary:
	# 中毒音效
	EventBus.sfx_requested.emit("poison")
	var events: Array = []
	for i in range(game_state["monsters"].size()):
		var m = game_state["monsters"][i]
		if m["current_hp"] <= 0:
			continue
		m["poison"] = m.get("poison", 0) + POISON_AMOUNT
		events.append({"type": "poison", "idx": i, "value": POISON_AMOUNT})
	return {
		"events": events,
		"meta": {},
	}
