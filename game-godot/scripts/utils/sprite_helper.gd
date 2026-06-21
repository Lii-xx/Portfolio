class_name SpriteHelper
## 精灵图动态切割工具
## monsters.png 为 5列x2行 网格，sprite_idx 0-9
##
## 注意：标准网格切割会让第 3、4 列怪物露出右侧邻居，且每格上下有空白边距。
## 这里参照 HTML 版（game.html .sprite-0~9）手动调整 region：
##   - X 轴：col 2,3 左移 24px（避免露出相邻怪物）
##   - Y 轴：row 0 下移 112px，row 1 上移 113px（裁掉格子上下空白，让怪物居中）
## 换算依据：HTML 容器 160x100，background-size 500% 200%（放大图 800x200），
## 原图 1536x1024，X 缩放 0.5208，Y 缩放 0.1953。

const COLS = 5
const ROWS = 2
# monsters.png 实际尺寸 1536x1024（5列x2行网格，每格 307x512）
const SPRITE_W = 307
const SPRITE_H = 512

# 参照 HTML 版的 region 偏移（原图坐标）
const X_OFFSET_COL_2_3 = -24
# 全局 X 偏移：让怪物在 TextureRect 内水平居中（往右移一点）
const GLOBAL_X_OFFSET = -25
# 第一行 Y=-113：region 顶部超出图片（透明），底部刚好到 399（第二行顶部），
# 避免露出第二行怪物的头。两行 region 都是 307x512，比例一致，显示大小一致。
const Y_OFFSET_ROW_0 = -113
const Y_OFFSET_ROW_1 = -113  # 第二行 Y=399，上移避免下方空白
# 第二行 region 高度：切掉底部空白，让怪物紧贴 region 底部（紧贴名字）
const SPRITE_H_ROW_1 = 450

static func get_monster_texture(sprite_idx: int, source_path: String = "res://assets/sprites/monsters.png") -> AtlasTexture:
	var atlas = AtlasTexture.new()
	var source = load(source_path) as Texture2D
	if source == null:
		push_error("Failed to load sprite sheet: " + source_path)
		return atlas
	atlas.atlas = source
	var col = sprite_idx % COLS
	var row = sprite_idx / COLS
	var x = col * SPRITE_W
	var y = row * SPRITE_H
	var h = SPRITE_H
	# 参照 HTML 版手动调整 region（避免露出相邻怪物 + 裁掉上下空白）
	if col == 2 or col == 3:
		x += X_OFFSET_COL_2_3
	x += GLOBAL_X_OFFSET  # 全局水平偏移，让怪物居中
	if row == 0:
		y += Y_OFFSET_ROW_0  # 第一行 Y=-113，顶部透明，底部到 399
	else:
		y += Y_OFFSET_ROW_1
		h = SPRITE_H_ROW_1  # 第二行切短，让怪物紧贴名字
	atlas.region = Rect2(x, y, SPRITE_W, h)
	return atlas
