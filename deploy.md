# 部署清单

## 服务器信息

- IP: 120.76.141.131
- SSH密钥: C:\Users\lh200\Downloads\Liixun.pem
- Web根目录: /var/www/html/
- 阿里云服务器

## 需部署的文件

### HTML页面

- index.html — 首页
- game.html — 卡牌游戏页(HTML版)
- game-godot-web.html — 卡牌游戏页(Godot版入口)
- decon-gacha.html — 抽卡机制拆解
- decon-tft-economy.html — 云顶之弈经济系统分析

### 静态资源

- Homepage background image.jpg — 首页背景图
- new background.png — 背景图
- monsters.png — 怪物图(game.html引用)

### Godot Web导出目录

- game-godot-web/ — Godot Web导出文件(index.html + .js + .wasm + .pck)
  - 由 Godot 编辑器导出"Web"预设生成，game-godot-web.html 通过 iframe 嵌入此目录

### exe下载目录

- download/ — Windows桌面版exe
  - download/CardRoguelike.exe — 由 Godot 编辑器导出"Windows Desktop"预设生成(embed_pck，单文件)

## 不部署的

game-godot/(Godot源码开发目录)、godot-editor/、godot-mcp/、个人网站-编辑区/、图片废稿/、游戏数值模拟测试/、monsters.xlsx、active-game.json、\~$\*.xlsx、export_presets.cfg

## 服务器配置提示

### .wasm MIME 类型

Godot Web导出包含 `.wasm` 文件，服务器必须返回正确的 MIME 类型 `application/wasm`，否则游戏无法加载。

阿里云服务器一般默认支持，若遇到问题，Nginx 配置加入：

```nginx
# /etc/nginx/mime.types 中应包含：
types {
    application/wasm wasm;
}
```

Apache 配置（`.htaccess`）：

```
AddType application/wasm .wasm
```

## 一键上传命令

```powershell
scp -r -i "C:\Users\lh200\Downloads\Liixun.pem" -o StrictHostKeyChecking=no index.html game.html game-godot-web.html decon-gacha.html decon-tft-economy.html "Homepage background image.jpg" monsters.png "new background.png" game-godot-web download root@120.76.141.131:/var/www/html/
```

(需在 D:\Desktop\求职\个人网站开发\ 目录下执行)

> 注意：game-godot-web/ 和 download/ 为目录，需加 -r 参数递归上传。
> 首次导出 Godot 游戏后，这两个目录才会生成。
