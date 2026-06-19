extends RefCounted
## 连劈效果: 造成4伤害3次（对齐HTML triple_hit）
## 第一击由 GameManager.play_card() 通用流程造成。
## 本效果负责"追加第2、3击"，通过 meta.extra_attacks 声明，
## 由 GameManager 统一执行（含死亡判定），保持主流程无 special 分支。

func execute(source: Dictionary, target_idx: int, game_state: Dictionary) -> Dictionary:
	var monsters = game_state["monsters"]
	if target_idx < 0 or target_idx >= monsters.size():
		return {"events": [], "meta": {}}
	var target = monsters[target_idx]
	if target["current_hp"] <= 0:
		return {"events": [], "meta": {}}

	var strength = GameManager.get_strength()
	var extra_attacks: Array = []
	# 追加第2、3击（共3击，第1击已由play_card处理）
	for i in range(2):
		if target["current_hp"] <= 0:
			break
		var dmg = DamageCalculator.calc_card_damage(source, strength)
		var dealt = DamageCalculator.apply_damage_to_monster(target, dmg)
		extra_attacks.append({"idx": target_idx, "value": dealt})

	return {
		"events": [],
		"meta": {
			"extra_attacks": extra_attacks,
		},
	}
