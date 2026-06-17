extends RefCounted
## 基类卡牌效果 - 所有特殊效果继承此类
## execute() 返回值（二选一，EffectRegistry 会自动归一化）：
##   - 旧式：Array         纯事件流
##   - 新式：Dictionary    { "events": Array, "meta": Dictionary }
##       meta 可声明 remove_self / extra_attacks 等，由 GameManager 统一处理，
##       避免在主流程里写 `if special == "xxx"` 分支。
## events 是供 UI 播放的事件流（dmg/heal/block/kill/buff...）

func execute(_source: Dictionary, _target_idx: int, _game_state: Dictionary):
	push_warning("base_card_effect.execute() should be overridden")
	return []
