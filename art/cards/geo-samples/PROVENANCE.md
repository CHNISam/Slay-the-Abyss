# 两张精修候选来源

这两份是 TASK-25/25.2 原始八卡任务中的重剑斩与透支，尚未获视觉量产批准。源图由本轮依用户要求生成，再手工重构原生几何；不是用户上传旧图，不直接复制 STS 卡图或官方角色贴图。参考只用于构图与旅行者衣装/元素语言，未以参考图像作为运行资源。

- 重剑 source.png SHA256：73530f37082b8fe1e412abefb317dab1697402e64d66f0bbe132ceff954285b6。选择刀锋撞岩近景并逐处修复金属面、刃口和岩石，握柄在裁切外。
- 透支 source.png SHA256：9092ea67f21c1c8022c7968cf608629313ae6d55cd449741fbee1003cd0b08a3. 重建掌腕、指形、袖口及晶体切面，未把原画当作可直接导入PNG。

衣装参考：[官方旅行者页面](https://wiki.hoyolab.com/pc/genshin/entry/3997?lang=es-es)。构图观察：[STS1 Heavy Blade 原版卡面存档](https://raw.githubusercontent.com/OceanUwU/slaytabase/main/docs/slay%20the%20spire/cards/heavyblade.png)、[Bloodletting 原版卡面存档](https://raw.githubusercontent.com/OceanUwU/slaytabase/main/docs/slay%20the%20spire/cards/bloodletting.png)。这些社区卡面存档不是素材授权库，未复制入本候选。

几何导出固定 Image Editor 103025f9095d8089e3f9bf097f4d0c5fe039d546；重剑保留的环境底稿来自本轮 Primitive 0526509e73d36b359d3c9bee1104718e4a600ed0 的拟合中间稿，主体手工修正。两份Lua保留导出器运行时代码和蒙版适配，不改署名、不声称全部是本项目原创。

许可证沿用 [编辑器GPL v3原文](../shared/licenses/EDITOR-GPL-3.0.txt) 与 [Primitive子运行时MIT原文](../shared/licenses/PRIMITIVE-SHAPE-MIT.txt)。具体第三方模板部分仍依其既有许可，不追加项目非商用限制；JSON几何的游戏IP、平台使用限制和是否可商用是不同问题。本记录只登记来源，不认定整游戏必须GPL，也不提供商业授权结论。

完整源图与大预览通过评审包单独交付，避免Git/CI重复下载；不因此隐去原生Lua/JSON和独立回归输入。当前sha在docs/legal/assets.json中登记，变更后必须重新审阅。
