extends RefCounted
## 秒杀效果: 玩家自损15HP，将一只非Boss怪物直接击杀
## 自损值集中在 SELF_DAMAGE 常量，方便后续调平衡

const SELF_DAMAGE: int = 15

func execute(_source: Dictionary, target_idx: int, game_state: Dictionary) -> Dictionary:
	var monsters = game_state["monsters"]
	if target_idx < 0 or target_idx >= monsters.size():
		return {"events": [], "meta": {"remove_self": true}}
	var target = monsters[target_idx]
	if target["is_boss"]:
		# Boss免疫秒杀：卡牌仍被消耗（打出即移除），但不产生任何效果
		return {"events": [], "meta": {"remove_self": true}}

	# 实际扣血量 = 怪物剩余血量，避免飘字显示错误的固定 15
	var dealt = target["current_hp"]
	target["current_hp"] = 0
	# 玩家自损（不致死，最低保留 1 血；若想允许自杀可去掉 maxi）
	game_state["player"]["hp"] = maxi(0, game_state["player"]["hp"] - SELF_DAMAGE)

	return {
		"events": [
			{"type": "dmg", "idx": target_idx, "value": dealt, "to_player": false},
			{"type": "kill", "idx": target_idx},
			{"type": "self_dmg", "value": SELF_DAMAGE},
		],
		"meta": {"remove_self": true},  # 秒杀牌打出后从卡组移除
	}
