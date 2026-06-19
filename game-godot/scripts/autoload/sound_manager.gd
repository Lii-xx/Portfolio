extends Node
## SoundManager - 音效管理器
## 统一管理BGM和SFX播放
## 文件不存在时静默跳过，不报错（T1框架：无音频文件也能正常运行）

var _bgm_player: AudioStreamPlayer
var _bgm_volume: float = 0.3
var _sfx_volume: float = 0.6

# 音频资源路径表（模块化：新增音效只需在此添加一行）
const BGM_PATHS = {
	"title": "res://assets/audio/bgm/title.ogg",
	"battle": "res://assets/audio/bgm/battle.ogg",
	"boss": "res://assets/audio/bgm/boss.ogg",
	"campfire": "res://assets/audio/bgm/campfire.ogg",
	"victory": "res://assets/audio/bgm/victory.ogg",
}

const SFX_PATHS = {
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"card_play": "res://assets/audio/sfx/card_play.wav",
	"card_draw": "res://assets/audio/sfx/card_draw.wav",
	"attack_hit": "res://assets/audio/sfx/attack_hit.wav",
	"attack_heavy": "res://assets/audio/sfx/attack_heavy.wav",
	"block": "res://assets/audio/sfx/block.wav",
	"heal": "res://assets/audio/sfx/heal.wav",
	"monster_die": "res://assets/audio/sfx/monster_die.wav",
	"player_hurt": "res://assets/audio/sfx/player_hurt.wav",
	"dice_roll": "res://assets/audio/sfx/dice_roll.wav",
	"buff": "res://assets/audio/sfx/buff.wav",
	"debuff": "res://assets/audio/sfx/debuff.wav",
	"poison": "res://assets/audio/sfx/poison.wav",
	"fire": "res://assets/audio/sfx/fire.wav",
	"level_up": "res://assets/audio/sfx/level_up.wav",
}

# 缓存已加载的音频流
var _bgm_cache: Dictionary = {}
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = linear_to_db(_bgm_volume)
	add_child(_bgm_player)

	# 连接EventBus信号
	EventBus.sfx_requested.connect(_on_sfx_requested)
	EventBus.bgm_requested.connect(_on_bgm_requested)
	EventBus.bgm_stopped.connect(_on_bgm_stopped)

	_preload_sfx()

func _on_sfx_requested(sfx_name: String) -> void:
	play_sfx(sfx_name)

func _on_bgm_requested(bgm_name: String) -> void:
	play_bgm(bgm_name)

func _on_bgm_stopped() -> void:
	stop_bgm()

## 预加载SFX到缓存（文件不存在则静默跳过）
func _preload_sfx() -> void:
	for sfx_name in SFX_PATHS.keys():
		var path = SFX_PATHS[sfx_name]
		if ResourceLoader.exists(path):
			_sfx_cache[sfx_name] = load(path)

## 播放BGM（同一首BGM不重复播放；文件不存在静默跳过）
func play_bgm(bgm_name: String) -> void:
	if _bgm_player.playing and _bgm_player.stream == _bgm_cache.get(bgm_name):
		return  # 同一首BGM不重复播放
	var stream = _bgm_cache.get(bgm_name)
	if stream == null:
		var path = BGM_PATHS.get(bgm_name, "")
		if path != "" and ResourceLoader.exists(path):
			stream = load(path)
			if stream:
				_bgm_cache[bgm_name] = stream
	if stream == null:
		return  # 文件不存在，静默跳过
	_bgm_player.stream = stream
	_bgm_player.play()

## 停止BGM
func stop_bgm() -> void:
	_bgm_player.stop()

## 播放SFX（文件不存在静默跳过）
func play_sfx(sfx_name: String) -> void:
	var stream = _sfx_cache.get(sfx_name)
	if stream == null:
		return  # 未缓存（文件不存在），静默跳过
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(_sfx_volume)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

## 设置BGM音量（0.0-1.0）
func set_bgm_volume(vol: float) -> void:
	_bgm_volume = clamp(vol, 0.0, 1.0)
	_bgm_player.volume_db = linear_to_db(_bgm_volume)

## 设置SFX音量（0.0-1.0）
func set_sfx_volume(vol: float) -> void:
	_sfx_volume = clamp(vol, 0.0, 1.0)
