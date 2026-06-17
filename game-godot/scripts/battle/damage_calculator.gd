extends Node
class_name DamageCalculator
## 伤害计算模块 - 处理力量/格挡/AOE/秒杀逻辑

## 计算卡牌最终伤害（含力量加成）
static func calc_card_damage(card: Dictionary, strength: int) -> int:
	if card.get("damage", 0) <= 0:
		return 0
	return card["damage"] + strength

## 对单体怪物造成伤害，返回实际伤害值
static func apply_damage_to_monster(monster: Dictionary, damage: int) -> int:
	if damage <= 0:
		return 0
	var actual_damage = damage
	if monster.get("block", 0) > 0:
		var blocked = mini(monster["block"], actual_damage)
		monster["block"] -= blocked
		actual_damage -= blocked
	monster["current_hp"] = maxi(0, monster["current_hp"] - actual_damage)
	return actual_damage

## 对玩家造成伤害，返回{damage, blocked}
static func apply_damage_to_player(player: Dictionary, damage: int) -> Dictionary:
	var blocked = mini(player.get("block", 0), damage)
	player["block"] = maxi(0, player.get("block", 0) - blocked)
	var actual = damage - blocked
	player["hp"] = maxi(0, player["hp"] - actual)
	return {"damage": actual, "blocked": blocked}
