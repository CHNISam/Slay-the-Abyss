# 牌堆图标候选（待 Owner 在编辑器核对）

现状（data/presentation/ui_theme.json `icon`）：drawPile=100149，discardPile=100150，exhaust=102049（加减号风格，观感差）。

仓库内未找到官方图片目录对这些 ID 的画面描述，无法离线确认更优替换，本轮未改 ID，不臆造新 ID。

候选：
- 抽牌堆：`icon.deck` 105046（已在主题使用，colour:true，但标 verify:true，尚未实机确认画面）。
- 消耗堆：保持 102049，或在编辑器图库搜索“火焰/燃烧”类图标后替换。
- 弃牌堆：需在编辑器图库搜索“卡牌/回收”类图标。

替换方式：仅改 ui_theme.json `icon.drawPile/discardPile/exhaust`，尺寸位置不变。
