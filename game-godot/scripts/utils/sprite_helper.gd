class_name SpriteHelper
## 精灵图动态切割工具
## monsters.png 为 5列x2行 网格，sprite_idx 0-9

const COLS = 5
const ROWS = 2
# monsters.png 实际尺寸 1536x1024（5列x2行网格，每格 307x512）
const SPRITE_W = 307
const SPRITE_H = 512

static func get_monster_texture(sprite_idx: int, source_path: String = "res://assets/sprites/monsters.png") -> AtlasTexture:
	var atlas = AtlasTexture.new()
	var source = load(source_path) as Texture2D
	if source == null:
		push_error("Failed to load sprite sheet: " + source_path)
		return atlas
	atlas.atlas = source
	var col = sprite_idx % COLS
	var row = sprite_idx / COLS
	atlas.region = Rect2(col * SPRITE_W, row * SPRITE_H, SPRITE_W, SPRITE_H)
	return atlas
