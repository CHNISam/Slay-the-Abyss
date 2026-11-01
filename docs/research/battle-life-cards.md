# 卡牌生命周期表现迁移

2026-10-30，TASK-29 / TASK-29.1，范围为岩系旅行者第一、第二幕。基线 `d4c4b255` 已有手牌UID插值、出牌飞向目标和只读事件队列；原缺口是命中后缩没，没有接上真实归堆。

## 核对资料与采用方式

资料来自本机固定缓存 `sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0.zip`，即社区反编译镜像 [aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，不是认证官方JAR，也没有原版客户端时长测量。只移植机制，不复制素材或整段实现。

- [UseCardAction.java:71–132](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java#L71-L132)：能力生效、回手、回抽、普通弃牌与消耗是不同目的地。此项目按已提交帧及最终牌堆的真实UID归属决定轨迹，不根据“攻击/技能”猜弃牌或消耗。
- [CardGroup.java:819–880](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java#L819-L880)：逻辑移堆与独立soul可视尾段分离。Lua复用现有OnUpdate，十个轻量原生cardTrail控件保留归堆尾段，尾段不继续占用出牌动作门。
- [AbstractCard.java:914–950](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java#L914-L950)：位置/缩放/旋转分别逼近，加速模式增加位置更新。既有手牌算法保留，新增开场抽牌从左下入手，以及弃牌/消耗回手起点修正；原生坐标和时长复用主题。迷你归堆轨迹采用项目现有smoothstep与轻弧线，未冒称这是原版贝塞尔常数。
- [DiscardAction.java:39–88](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DiscardAction.java#L39-L88) 与 [ExhaustAction.java:80–127](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ExhaustAction.java#L80-L127)：保留手动/轮末弃牌及消耗的核心原始处理，表现只读取其结果。消耗轨迹通往顶部真实消耗图标，使用独立语义色，能力牌通往玩家并标注“能力生效”，保留牌出现“保留”短提示。
- [EmptyDeckShuffleAction.java:42–69](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/EmptyDeckShuffleAction.java#L42-L69)：洗牌使用独立视觉传输，最多十张显式演出。此项目同样限制十个同时可见控件，更多移动在Lua等待，轨迹由右侧弃牌堆回左侧抽牌堆，不调用随机数。

本轮实际读取源文件SHA256：

| 文件 | SHA256 |
| --- | --- |
| AbstractCard.java | bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61 |
| CardGroup.java | 03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8 |

其余源文件均来自同一个固定提交ZIP，本机提取副本在该工作树`.artifacts/sts/`，没有作为本项目源码提交。

## 实现边界与验证

`abyss_card_flow`仅对相邻hand/draw/discard/exhaust快照以及最终实际battle按UID做差分；不添加或消费核心事件，不重排事件，不调用核心命令或RNG。出牌卡保留到已提交归堆帧，再交给独立迷你卡尾段。取消、故障和换战清除全部池状态；十个控件固定复用，不在每帧创建原生对象。

- `card_flow_feedback.lua`：真实Combat命令与生产Feedback，打击至弃牌、岿然不动至消耗、燃烧能力生效、正常轮末整手弃牌与随后洗牌。逐UID验证可见终点；逐字段比较完整battle（含事件和随机状态）无写入。旧Feedback运行新回归失败，新实现通过。
- `card_flow.lua`：消耗顶栏坐标、保留、洗牌反向、能力分类、25移动最多十控件、取消清理。
- 原`feedback_polish`17、`card_feedback`10、`feedback_continuous_cards`4项通过。原`battle_card_motion`5项保留悬停/回拖/UID复位断言，先等开场入手完成再测静态起点；新战斗补抽牌堆起点与最终手牌目标断言。
- 工程门禁由中控使用完整集成及新模块架构登记后统一执行；该工作树最初缺luaparse依赖的启动失败不计通过。

没有本轮官方导入、PC或实体手机视觉/听验；池大小和无规则写入是离线证据，不能作为实机帧率数据。消耗采用原生缩小归入消耗堆，未移植原版碎片粒子素材；手机可读性及连续大量归堆实际观感待同候选审查。

## 完整CI发现的洗牌入口边界

PR378完整CI的`battle_draw_motion`暴露真实空堆洗牌在两次UI绘制之间一次完成时，单看先前discard与最终hand会漏掉已提交的reshuffle中间draw帧。此时仍必须先归抽牌入口，不能把旧测试改成弃牌起点掩盖缺陷。

最小修复仅在CardView按上次绘制所见的事件对象末尾，扫描本批新增reshuffle帧里的draw UID；普通反馈的中间帧和一次完成的直接draw均保留抽牌来源。已见过的旧reshuffle不影响之后直接从弃牌/消耗堆回手；核心消费复用并清空事件数组后，新的短批仍按新事件识别。未修改Combat或Events。新辅助复杂度9、手牌姿态10、renderCards15，均在既有15上限内。

对应`battle_draw_motion`保持真实draw入口、缩放固定速率、最终目标、UID/升级与完整状态/RNG断言，补明确直接回手真实源堆、旧事件不污染、事件数组消费后新洗牌和新战斗开场入手/未知生成UID静态来源。该夹具5组以及手牌motion5、卡流1+4、拖动边界7、回拖取消5组专项通过；完整门禁及重新构建由中控基于最终集成继续执行。
