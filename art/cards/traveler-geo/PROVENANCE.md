# 来源、版本与许可边界

三张现行源资产及旧Heavy否决历史，均以各卡 `asset.json` 为准。本目录不保存第三方参考原图、私聊标识、Library ID或绝对云路径；不复制完整诊断/整卡渲染包。2026-10-27的新两样离线认可只绑定新hash，不覆盖旧否决，不等于官方导入、设备通过或量产许可。

## 实际生成链

均由内置imagegen生成，再按源坐标手工重构原生轮廓；不是把原作PNG导入游戏。工具未公开模型版本/seed，不补造。实际提示词逐字保留，元数据记载请求输入的SHA和职责；工具请求尺寸不冒充实际PNG尺寸。

- **Armaments**：风格修订03的source-02，原生为无手修订03上侧修复版。`prompt.txt`输入1为此前自生成护腕设计（`2771b2fd5e1e62c5fcf69e20c351af2574f2bf69669baa281b4a62822030f84d`），只借白银/淡蓝护腕、不保留人体手；输入2为[STS Armaments存档](https://static.spire.moe/image/sts/portraits/red/skill/armaments.png)，仅观察绘画明暗分组（SHA `e19d9f43a256ed7f08ab19295da5e46fcf68270b7a7f9057a8f8a07ed7f461d8`）。本轮不改该资产字节与认可。
- **Cleave**：身份修复第1次生成source-01，`prompt.txt`；实际输入为[KQM岩旅行者实机记录](https://keqingmains.com/geo-traveler/)第30帧、[HoYoWiki星陨剑图标](https://bbs.hoyolab.com/hoyowiki/picture/character/旅行者(岩)/battle_talent_1/battle_talent_1.png)及Armaments风格参考。前两者仅确认低宽分段圆岩/环顶/琥珀折线结构，后者仅绘画风格。KQM是第三方实机，不称官方宣传视频；原参考像素不入库。
- **Heavy第1步**：`prompt.txt`生成source-01（SHA `9010fe24ff0c1220d54e724943c6f31a2e3524f1d127a0c46dd35bfb396531ae`）。实际输入为[HoYoWiki旅行者立绘](https://wiki.hoyolab.com/pc/genshin/entry/2674?lang=en-us)、官方域模型idle的未改第0帧以及Armaments绘画风格。只使用荧原衣装的连续白蓝腰裙/金色拱腰饰；官方武器类为单手剑，不将卡名误读成双手剑。
- **Heavy第2步**：`prompt-repair.txt`只以上一步source-01为编辑目标，把剑尖先接触修正为同一剑刃中前段单点接触、连续剑尖伸出。保留荧衣装、单剑/单敌；最终source-02 SHA `1cf7dec3ef1f9ae369837204c24b0ce727142909f200c225d252dd85760bdbfc`。其1882×836原字节保留。两步prompt、输入/输出hash、模式和实际生成耗时在 `generation.steps` 完整串接；中间源只留hash，不再次上传。

第三方参考URL/hash只用于来源与身份核对，不是素材授权库。HoYoWiki为官方域与社区共建平台，不把每个上传记录都称为官方宣传片。前序[官方荧页面](https://wiki.hoyolab.com/pc/genshin/entry/3997?lang=es-es)观察图 `4fde17bbb019e088d726e9948a8b0b146250a66ef2b41032cea7a9a6d86b8b9e` 未直接输入Armaments最终生成；不补造该关系。

## 旧Heavy否决历史

旧紧凑Heavy曾获较早离线正评，随后因“通用战士、缺少岩旅行者身份”被否决。`heavy_blade/asset.json` 的 `supersededRevisions` 保留原source、prompt、JSON、规范化Lua、preview完整hash/字节和原Lua恢复信息，旧正评仅在撤销记录的history中。旧状态固定为 `revision-required-character-identity`、scope为空、`productionRuntimeApproved=false`、`appliesNewApproval=false`。

原文件及完整旧来源可从[固定Git历史dc439fe](https://github.com/CHNISam/Slay-the-Abyss/tree/dc439fe83279a4f75ce526ecc757b7da8b6cc7cf/art/cards/traveler-geo)恢复。旧源图输入为Armaments绘画风格与[STS Heavy Blade存档](https://static.spire.moe/image/sts/portraits/red/attack/heavy_blade.png)（SHA `689b321f0166fec64c9b849dc22733d7be095f55c2a248eade355b1ba40b1603`），只研究亮刃与单一目标接触方法；此方法参考没有提供角色身份。旧两张PNG仍由Git/LFS历史承载，当前树不重复上传。新样通过不能使这些旧hash恢复批准。

## 原生与预览

固定[Miliastra Image Editor 103025f9095d8089e3f9bf097f4d0c5fe039d546](https://github.com/1475505/Miliastra-image-editor-webui/tree/103025f9095d8089e3f9bf097f4d0c5fe039d546)。JSON不变；Lua仅删除导出器多余的1个末尾LF，保留最终LF。每卡 `files.native-art.lua.originalExport` 保存原hash/字节和精确移除数。回归加回LF后必须还原原hash，完整AST及真实绘图表须相等；不改代码或以冻结资产为由关闭空白门禁。4×预览仍为原真实无快照Lua回读字节，未重新生成。

原生仅基础形状100001/100002/100003及已有图库106056/106057；每卡3个图库图元，不嵌源PNG、不新增外部PNG导入路线。已读取图库资源为：

| 原生ID | 固定编辑器公开URL | 已读取SHA256 |
|---|---|---|
| 106056 | <https://oss.070077.xyz/images/sprite/106056.png> | `62492988816157c79d460d97d32238e16e40b8d72b7c3be192b11f764332c9cb` |
| 106057 | <https://oss.070077.xyz/images/sprite/106057.png> | `dc2484a8c1dc677deb2f7f28ca33932a83abf7c88ed320d69da903d37c11b963` |

这只记录既有读取证据，本登记不联网、不复制图库PNG。新身份在source→native仍保留，非通用金色符号。整卡1×0差、4×Cleave11/Heavy4像素strict FAIL保留；没有提高容差，离线认可不改写结果。

## 许可与验收边界不变

沿用 [THIRD_PARTY_NOTICES.md](../../../THIRD_PARTY_NOTICES.md)、[LICENSE-SCOPE.md](../../../LICENSE-SCOPE.md)、[编辑器GPL v3](../shared/licenses/EDITOR-GPL-3.0.txt)与[Primitive子运行时MIT](../shared/licenses/PRIMITIVE-SHAPE-MIT.txt)。导出Lua按既有 `editor-runtime` 登记；源图、几何、预览、元数据为 `game-ip-ai-redraw`。类别表示来源，不是清关或新授权。

项目原有非商业政策与项目方商业化权利声明不变，第三方运行时仍适用各自许可；本记录不授予游戏IP再许可、不提供商业清关结论。官方导入、PC、实体Android、真实字体/XYZ/清理、加载/多卡性能仍未验；普通B=4、稳定批次0，不恢复队列或扩大卡池。
