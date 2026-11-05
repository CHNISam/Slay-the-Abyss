# 结算页：具体参照、项目事实与原型边界

更新于 2026-11-05。此页记录用户已认可结算设计的来源。公开副本与私人界面原型都不是原生游戏实现或平台验收。

## 明确的原版参照

1. 实际查看了 [Interface In Game / You are slain](https://interfaceingame.com/screenshots/slay-the-spire-you-are-slain/)，画面为初代 Slay the Spire V2.0、1920×1080。取用上方横卷标题、中央左右对齐的单列统计、分隔线、暗色战斗场景及下方主按钮的层级。图片没有嵌入页面，不冒称已精确复刻原版纹理或字体。
2. 固定源码参考 [aeubanks/sts @ 319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。这是第三方 CFR 反编译镜像，不是 Mega Crit 官方开源发布。
   - [DeathScreen.java L98–108](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/DeathScreen.java#L98-L108)：返回按钮、胜败横幅。
   - [GameOverScreen.java L397–435](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/GameOverScreen.java#L397-L435)：暗色统计覆盖层，单列标签和值；本原型只保留项目已知统计，不照搬击杀加分计算。
   - [VictoryScreen.java L62–86](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/VictoryScreen.java#L62-L86)：胜利同样复用 GameOverScreen 与居中返回按钮。胜利布局依据此源码；不把失败截图谎称为胜利截图。

本次没有复制原版解锁进度条，因为项目尚无持久存档，也不能将作者升级与玩家游戏解锁混为一谈。底部支持文案是适配新增位置，不是假进度条。

## 项目源码已核实内容

基线是 FurinyaWorks/Slay-the-Abyss develop `87c944f3d1ae89b01470cf89d6f7cc96cc4017ab`，只读核验，未修改该仓库。

- [胜败标题与统计](https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/src/lua/abyss_game_ui_menu_view.lua#L88-L137)：双幕挑战完成、旅途在此中断；抵达层数、战斗胜场、用时、卡组等。顶部“胜利样例 / 失败样例”使用明确标注的独立样例数字，不能作为真实通关战绩。
- [重新启程与结束并结算](https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/src/lua/abyss_game_ui_menu_view.lua#L105-L110)：重新启程不提交，结束并结算才进入平台结算。本浏览器没有平台连接，点击会显示“本次点击没有提交战绩”，不会假装提交成功。
- [退出原文](https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/src/lua/abyss_game_ui.lua#L443-L450)：存档功能需作者达到创作者 4 级后开放，喜欢的话欢迎点赞支持。帮助作者提升等级。
- [当前比赛不依赖存档](https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/docs/PUBLISHING.md#L73-L75)：不承诺退出续玩、跨局进度或历史。本原型已移除可用的保存并退出 / 继续游戏入口，战斗与地图改为当前页面内存状态，刷新或离开即丢失。保留当前界面中的取消返回，不等于存档。

## 彩蛋交互保留，图像不在公开副本分发

- [触发条件](https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/src/lua/abyss_game_ui.lua#L213-L219)：仅胜利页、手动“查看彩蛋”；不自动播放，不在失败页提供，不产生奖励。
- [原文与返回](https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/scripts/victory-easter-egg-layout.mjs#L12-L18)：感谢您的游玩~！ / 返回结算。
- [能力开关](https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/scripts/art-features.mjs#L10-L49)：底层 normalize API 默认全 false；候选 CLI 的 candidateArtDefaults 则为 menuBackground=true。实际入口取决于候选开关与挂载，不能笼统称正式默认关闭；本页不改变任何开关，也不证明当前官方候选可用。
- 私人原型画面使用项目 [preview-native.png](https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/art/characters/key-visual/traveler-geo/official-landscape-v1/preview-native.png)，SHA256 `e23d1daac5e7046f9119edbd6179fd16fa31abd245c24d395adfd1af31a91a43`，与固定源码 LFS 指针一致。原生几何画预览为480×270，放大有块状细节，这是既有资产，不是新增AI绘制。
- [素材来源记录](https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/art/characters/key-visual/traveler-geo/official-landscape-v1/source-provenance.json#L7-L40)：2022 HoYoverse / ufotable 概念预告中的荧，由 GameLeap 镜像取得；不是《未行之路》，版权属于原权利方。该第三方画面不复制到本公开目录，也不热链为 UI 组件。公开版保留手动打开、来源说明和返回结算，不宣称原创或许可扩大。

## 验证层级

仅浏览器原型与 Node 模型测试。真实平台存档、结算提交、创作者等级、原生画布与实机触控均未由本次原型验证。原型样例可用不代表任何平台功能解锁。
