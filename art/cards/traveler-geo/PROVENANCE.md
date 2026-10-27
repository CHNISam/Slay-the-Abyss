# 来源、版本与许可边界

本目录保全两张源图及必要的评审反例，不保存第三方参考原图、私人会话标识或云端绝对路径。当前裁决以各卡 `asset.json` 的 `approval` 为准，本页只说明来源与技术版本，不独立授予设计批准。2026-10-27 较早的离线正评保留为历史；后续人审已指出重剑斩缺少岩旅行者身份，因此它是待改反例，整备武装仅保留为离线身份/质量参考。JSON、实际LFS源PNG、提示词和预览PNG字节保全；两份Lua仅做下述可逆EOF规范化。入库SHA见各卡 `asset.json` 和 `docs/legal/assets.json`，原导出SHA另保留在 `originalExport`。不引用私聊全文，不将历史好评扩大为当前最终设计、官方导入、性能或量产许可。

## 生成源与实际提示词

两张源图均由本任务内置 **imagegen** 生成，再按源坐标手工重构原生轮廓；不是用户上传，也不是把原作PNG直接装入运行资源。工具未公开模型版本/seed，不补造这些字段。提示词中的图像引用按实际输入记录如下，参考图本身不复制入仓库：

| 源图 | 实际版本与输入职责 |
|---|---|
| `armaments/source.png` | 风格修订03的第02源图；实际最终提示词在同目录 `prompt.txt`。图1是先前自生成护腕设计（SHA256 `2771b2fd5e1e62c5fcf69e20c351af2574f2bf69669baa281b4a62822030f84d`），只借用白银/淡蓝护腕设计，不保留人体和手；图2为STS Armaments原卡，只观察成熟绘画明暗分组，不复制角色、装甲或构图。原生为无手修订03的上侧修复版。 |
| `heavy_blade/source.png` | 紧凑重剑源图，实际只有1次生成；实际提示词在同目录 `prompt.txt`。图1为本目录整备源图，仅借绘画/光影语言；图2为STS Heavy Blade原卡，仅研究连续亮刃、单一暗目标与接触/抗力关系。原生为compact重剑版。 |

[STS Armaments原卡存档](https://static.spire.moe/image/sts/portraits/red/skill/armaments.png) 的已观察SHA256为 `e19d9f43a256ed7f08ab19295da5e46fcf68270b7a7f9057a8f8a07ed7f461d8`；[Heavy Blade原卡存档](https://static.spire.moe/image/sts/portraits/red/attack/heavy_blade.png) 为 `689b321f0166fec64c9b849dc22733d7be095f55c2a248eade355b1ba40b1603`。这些公开社区存档是方法观察来源，**不是素材授权库**。

旅行者设计血缘参考沿用[官方荧页面](https://wiki.hoyolab.com/pc/genshin/entry/3997?lang=es-es)。既有观察图SHA256为 `4fde17bbb019e088d726e9948a8b0b146250a66ef2b41032cea7a9a6d86b8b9e`；它用于前序人物设计观察，**未作为本次整备最终source-02的直接生成输入**，也不作为运行素材。公开可访问和官方角色身份不构成额外素材授权。

## 原生导出与预览

固定工具为 [Miliastra Image Editor `103025f9095d8089e3f9bf097f4d0c5fe039d546`](https://github.com/1475505/Miliastra-image-editor-webui/tree/103025f9095d8089e3f9bf097f4d0c5fe039d546)。两份JSON/Lua不重新导出、不修改模板/运行时或绘图表；为通过既有 `git diff --check`，每份Lua仅移除原导出末尾多余的1个LF，保留一个最终LF。JSON及其它输入不变，原私有导出也不改。4×预览仍是原导出的真实无快照Lua读回产物。可选场景快照只服务编辑回导，不能取代真实绘图表的验收。

### Lua入库文本与原始导出

| card_id | 原始导出SHA256 / 字节 | 入库规范化SHA256 / 字节 | 精确变换 |
|---|---|---|---|
| `armaments` | `1ab3309300aa54f75214aff4aafd41e0af604ab5909508209f71d246ab12e9b6` / 350790 | `b120cb5d4d30372611c539b69c8b04af1c8ea5feafbdb561c1eabb37443c8a04` / 350789 | 仅移除末尾1个LF |
| `heavy_blade` | `0f8ad60f1e7ff4d4d10fe4bb69b62297a92a5e268c1e13d471f9a4c4413ba54b` / 624749 | `db35c898e427d1487766484817384b190407d7cc46ec3a2212ee878db39e1e47` / 624748 | 仅移除末尾1个LF |

回归将LF规范化的入库文本加回精确1个LF，要求字节数与原始SHA均匹配，再比较完整 `luaparse` AST和无快照真实绘图表完全一致。这个可逆文本变换不修改图元、蒙版、清理代码或预览，也不改变任何平台待验状态；不以冻结资产为由关闭空白门禁。


原生只引用基础形状100001/100002/100003和已有图库106056/106057；不嵌源PNG，不新建自定义图片导入路线。每卡3个图库图元，实际回读时使用的两份资源为：

| 原生ID | 固定编辑器公开读取URL | 已读取SHA256 |
|---|---|---|
| 106056 | <https://oss.070077.xyz/images/sprite/106056.png> | `62492988816157c79d460d97d32238e16e40b8d72b7c3be192b11f764332c9cb` |
| 106057 | <https://oss.070077.xyz/images/sprite/106057.png> | `dc2484a8c1dc677deb2f7f28ca33932a83abf7c88ed320d69da903d37c11b963` |

资源URL/摘要仅记录既有离线读取证据，本切片不联网重新下载，也未把第三方贴图单独复制入目录。离线图库预览不证明官方设备RGBA、混合XYZ或GPU蒙版等价。

## 许可保持原边界

沿用项目 [THIRD_PARTY_NOTICES.md](../../../THIRD_PARTY_NOTICES.md)、[LICENSE-SCOPE.md](../../../LICENSE-SCOPE.md)、[编辑器GPL v3原文](../shared/licenses/EDITOR-GPL-3.0.txt) 与 [Primitive子运行时MIT原文](../shared/licenses/PRIMITIVE-SHAPE-MIT.txt)。导出Lua含上游运行时代码，依既有 `editor-runtime` 类别登记；源图、几何、预览及资产登记元数据沿用 `game-ip-ai-redraw` 类别。类别表示来源，不是清关或新授权判断。

项目原有非商业政策与项目方商业化权利声明不变；第三方模板部分继续适用各自许可，不追加项目非商业限制，也不以这两份导出推定整游戏的许可。游戏IP、生成服务条款、平台使用条件与第三方运行时是不同问题；本记录不授予游戏IP再许可、不提供商业清关结论。正式源资产保全不会把未验的运行时接线、清理、平台导入、多卡/设备性能或全卡池批准改写为通过。
