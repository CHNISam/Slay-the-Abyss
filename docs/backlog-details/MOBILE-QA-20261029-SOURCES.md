# 10/29 核验项、可复用实现与授权边界

## 1. 录音要求确认的事项

| 问题 | 核验结论 | 证据/限制 |
|---|---|---|
| 试玩上传10MB/上限20MB是什么 | 属于关卡存档/试玩上传数据；不是图片配额或玩家续玩存档。20MB数值及压缩口径尚未独立核定 | [专项调查](../art/UPLOAD-BUDGET-20261029.md)，明确实际上传实验，不拿JSON估算当测量 |
| 窃贼是否开局显示逃跑倒计时 | 固定PC代码不采用开局固定倒计时。先偷钱攻击；两次后随机转防御准备或再突进；准备动作后设置ESCAPE，下一次执行逃跑 | Looter.takeTurn/getMove，Smoke Bomb阶段Intent.DEFEND，不误写成从该回合一开始就ESCAPE |
| 地图能否查看牌库 | 固定PC版允许MAP打开Master Deck，并保留返回地图的界面栈逻辑 | TopPanel.updateDeckViewButtonLogic显式包含MAP，不把PC结论冒充已核对官方手机实现 |
| 地图药水能否查看/使用 | TopPanel有药水命中、缩放、点击打开PotionPopUp；查看与使用必须分开。具体MAP状态与每种药水使用限制需连同update入口/AbstractPotion.canUse再复核 | 已读updatePotions，不据此宣称所有药水在地图都能用；本项目要求地图只读查看，使用按现有规则 |
| 打击类说明是不是乱加 | 原版Strike_Red有STRIKE和STARTER_STRIKE标签，6基础伤害；这个机制身份确实存在。Java从语言包取DESCRIPTION，本轮没取得对应中文语言包，不能声称查到了原版中文逐字文案 | 精简本项目正文，不删除标签/按中文名字猜类别；保留关键词说明及剑势如虹计数合同 |
| 伤害公式是否必须显示 | 没有证据要求玩家默认看力量0/取整链。本项目截图1179真实攻击和伤害均10，公式冗余是表现问题 | 默认最终值，必要修正按需展开；不由录音“4”推导结算错误 |
| 点击敌人为何看不到易伤 | 1181第1/2页、1182第二页已显示易伤；不是状态丢失，而是分页发现性差 | 统一从头像查看所有状态、允许滚动；原版PC/手机的具体触控入口差异未逐设备验收，不假称完全相同 |
| 出牌瞬间红色不可打是否正常 | 当前源码把短暂busy/inactive合并进enabled并驱动暗化；截图1189支持用户反馈。可以不改规则锁而修视觉 | 没有验证原版每帧渲染，不能以“原版绝不会”作伪证；见主报告代码链 |
| 营地/商店应否连续滚动 | 平台原生GridScrollerControl支持连续滚动、滚动条与可见项复用，可满足用户需求 | 现有分页形式不证明“完全没有代码复用”；改共享列表而非照搬Java界面 |
| 原版移动交互代码能否直接搬 | 已核对的是社区CFR反编译PC代码，不是官方公开授权的iOS/Android源码。不能保证逐行迁移后手机手感正确 | 仅作行为对照；在千星原生Lua输入契约下独立实现，保留点选后备 |
| 局内存档是否创作者4级 | 2025-10-31官方“等级权益调整”明确从Lv5降到Lv4；本轮未登录核验用户账户当前权益 | 这是创作者权限，不是玩家要升4级。权限开放也不等于游戏已实现完整保存/恢复 |
| 点赞是否直接帮作者升等级 | 本轮未取得可证明点赞→经验的当前官方计算规则，不承诺具体因果或一次点赞解锁 | 先用“目前退出后无法继续本局。喜欢这款游戏，欢迎点赞支持。”；“帮助作者提升等级”须核定规则后再启用 |

原版固定参考：`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，是社区反编译参考而非版权许可。
- [Looter.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/Looter.java)，blob `62180226216c6e8fa1739b46b81e60e62a9be457`。
- [TopPanel.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/panels/TopPanel.java)，blob `ff4ccdc1344f2cdd4dcf8034dd72196bf7bf0669`，updateDeckViewButtonLogic/updatePotions。
- [Strike_Red.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/red/Strike_Red.java)，blob `ea57b7327ab094e49e4169661411b02999635e39`。
- [官方奇匠等级调整公告](https://www.taptap.cn/moment/733285371080609487?group_id=201765)及[原神千星奇域官方微博公告页](https://www.sina.cn/news/detail/5227779438151916.html)。公告是功能门槛证据，不是当前账户权限或点赞公式证据。

## 2. 不从零造轮子，但分清“直接复用”和“参考后实现”

| 候选 | 可复用内容 | 本项目落点与验收 |
|---|---|---|
| 千星原生GridScrollerControl | 官方滚动列表、可见项复用、RefreshItems、横/纵方向、滚动条 | TASK38：营地/商店/牌库/选择器共用CardDisplay。项必须来自控件模板；仅把子控件塞在视窗下不会滚动。复用时重新绑定UID，回收时清事件/选中态，滑动不误购 |
| 现有CardDisplay/CardSkin及药水、状态组件 | 已认可奖励卡面、动态费用/升级/关键词，原生图标与确认弹层 | TASK38/4.4/4.7：替换纯文本卡块，不另造卡牌数值文本；用同一库存/单位数据源、只读查询不触发事务 |
| libGDX GestureDetector（固定1.13.1） | tap区域、longPress、pan、fling速度追踪的职责分离 | TASK30：参考手势分类与终止原则，Lua独立实现；不照搬默认20px/1.1秒等参数，也不等长按结束才响应拖动 |
| libGDX ScrollPane（已读主分支实现） | 滚动/惯性/边界与子控件焦点协调 | 原生GridScroller优先；只有平台缺口明确才参考算法，选定版本后锁SHA并验证。它依赖Scene2D，不能在千星直接运行Java |
| STS PC AbstractPlayer/卡牌交互参考 | 目标预览、合法释放、取消与动画分离的对照 | 现有任务已有来源链，继续复用；不沿用触屏无效carry作为手机验收。用户截图证明需求与旧桌面行为有冲突 |

原生指南：[网格视窗](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhfkrr0i7gds)；[已读正文镜像](https://github.com/8itlab/genshin-miliastra-mcp/blob/main/knowledge/official/guide/mhfkrr0i7gds.md)，blob `29d5feebda833e8ec4a483c237e2e9654bd318f8`；[客户端API](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhtakr07vej4)。落地前核对安装客户端的实际可用字段，不套Unity/DOM API。

库参考：[GestureDetector 1.13.1](https://github.com/libgdx/libgdx/blob/1.13.1/gdx/src/com/badlogic/gdx/input/GestureDetector.java)，blob `582f05db76bd99cfc8f8d599ec914efeae794aed`；[ScrollPane](https://github.com/libgdx/libgdx/blob/master/gdx/src/com/badlogic/gdx/scenes/scene2d/ui/ScrollPane.java)；[libGDX LICENSE](https://github.com/libgdx/libgdx/blob/master/LICENSE)。这不是批准引入整个引擎。任何实际代码移植须先核许可/NOTICE、锁版本、满足项目SCOPE的第三方复用审批；本PR未复制第三方实现。原作反编译代码不因能在GitHub读到就成为可直接搬运的开源代码。

## 3. 无障碍与可操作性落地标准

Apple的[UI Design Tips](https://developer.apple.com/design/tips/)建议触控区域至少44×44pt；Android官方[触摸目标尺寸](https://support.google.com/accessibility/android/answer/7101858?hl=zh-Hans)建议48×48dp并留8dp间隔。作为本项目手机目标：主要操作按44pt/48dp量级实测，而不是把1280画布坐标直接写44。记录真实屏幕尺寸、缩放关系和实际命中范围。可视图标可以小于触区，但扩大后的结束回合/弃牌堆热区不能重叠或被上层透明控件拦截。

[WCAG2.2 2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)的24×24 CSSpx及间距例外适用Web目标标准，不是“手机44px”的同义语，也不是本游戏自动合规证明。[2.5.7拖动替代](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html)支持保留点牌再点目标的非拖动途径。图元UI是否暴露系统辅助功能语义尚未核定，不能只量尺寸就宣称全面无障碍通过。

关键数字/卡文不裁切、不出现孤立标点占行；放大字体不靠挤压按钮解决。当前节点/选中卡用结构标记加颜色，不能只靠呼吸或细微色差。至少核对16:9与用户宽屏、缺口安全区、字号设置、长文本、多状态、0/1/多项列表；用户实测嫌小即保留可读性缺口，不以桌面截图“看得见”关闭。
