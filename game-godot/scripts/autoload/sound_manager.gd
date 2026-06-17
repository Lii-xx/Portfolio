extends Node
## SoundManager - 音效管理器
## 统一管理BGM和SFX播放

var _bgm_player: AudioStreamPlayer
var _sfx_players: Dictionary = {}  # name -> AudioStreamPlayer
var _bgm_volume: float = 0.3
var _sfx_volume: float = 0.6

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = linear_to_db(_bgm_volume)
	add_child(_bgm_player)
	
	# 连接EventBus信号
	EventBus.sfx_requested.connect(_on_sfx_requested)
	EventBus.bgm_requested.connect(_on_bgm_requested)
	EventBus.bgm_stopped.connect(_on_bgm_stopped)

func _on_sfx_requested(sfx_name: String) -> void:
	play_sfx(sfx_name)

func _on_bgm_requested(bgm_name: String) -> void:
	play_bgm(bgm_name)

func _on_bgm_stopped() -> void:
	stop_bgm()

## 播放BGM
func play_bgm(name: String) -> void:
	var stream = _create_bgm_stream(name)
	if stream == null:
		return
	_bgm_player.stream = stream
	_bgm_player.play()

func stop_bgm() -> void:
	_bgm_player.stop()

## 播放SFX
func play_sfx(name: String) -> void:
	var stream = _create_sfx_stream(name)
	if stream == null:
		return
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(_sfx_volume)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

## 合成BGM - 简单氛围音
func _create_bgm_stream(name: String) -> AudioStream:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	return gen

## 合成SFX - 简短音效
func _create_sfx_stream(name: String) -> AudioStream:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	return gen
