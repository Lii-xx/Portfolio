extends RefCounted
## 旋斩效果: 伤害已在 GameManager.play_card() 中处理（消耗全部能量，伤害=damage×能量+力量）
## 本效果脚本为空壳，仅用于注册到 EffectRegistry

func execute(_source: Dictionary, _target_idx: int, _game_state: Dictionary) -> Dictionary:
	return {"events": [], "meta": {}}
