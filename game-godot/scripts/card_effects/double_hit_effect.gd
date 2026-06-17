extends RefCounted
## 连劈效果: 该卡本身的第一击已由 GameManager.play_card() 通用流程造成。
## 这里负责"追加第二击"，并对目标应用伤害。
## 通过 meta.extra_attacks 把"要打的目标+伤害值"声明出去，
## 由 GameManager 统一执行（含死亡判定），从而不再在主流程里写 special 分支。

func execute(source: Dictionary, target_idx: int, game_state: Dictionary) -> Dictionary:
	var monsters = game_state["monsters"]
	if target_idx < 0 or target_idx >= monsters.size():
		return {"events": [], "meta": {}}
	var target = monsters[target_idx]
	if target["current_hp"] <= 0:
		return {"events": [], "meta": {}}

	# 第二击伤害 = 卡牌伤害 + 玩家力量（与第一击同一公式）
	var strength = GameManager.get_strength()
	var dmg = DamageCalculator.calc_card_damage(source, strength)
	# 在效果内直接结算伤害，让 extra_attacks 只承担"声明已发生的事实"职责
	var dealt = DamageCalculator.apply_damage_to_monster(target, dmg)

	return {
		"events": [],
		"meta": {
			# extra_attacks 让 GameManager 补发 dmg/kill 事件用于 UI 飘字与死亡判定
			"extra_attacks": [{"idx": target_idx, "value": dealt}],
		},
	}
