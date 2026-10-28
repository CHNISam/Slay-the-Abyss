# 商店、宝箱、营地的源码交互移植

2026-10-28，TASK-4.7 / TASK-4.8 / TASK-4.9。用户明确要求先移植原版体验，并补上开箱的蓄力与爆发感。岩金主题和现有资源规则保留；这次变更替换相关陈列与交互，不将原型数据当成规则。

## 方法对照

固定社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是认证原版客户端运行证据。

| 实际读取的方法 | 本次平台适配 |
|---|---|
| [ShopScreen.initCards / updateCards / update / renderCardsAndPrices](https://raw.githubusercontent.com/aeubanks/sts/319009d5df0a82d9fb0f23cc22322286c6a87ec0/shop/ShopScreen.java) | 五张职业牌上排、两张无色牌下排；鼠标悬停放大 1.2 倍、价格下移；触屏选取后明确购买，鼠标直接购买；取消、遮挡和报价变化使选择过期。 |
| [AbstractChest.open](https://raw.githubusercontent.com/aeubanks/sts/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rewards/chests/AbstractChest.java)、[CombatRewardScreen.setupItemReward / update / render](https://raw.githubusercontent.com/aeubanks/sts/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/CombatRewardScreen.java) | 纵向奖励列表，直接点领取；四槽覆盖金币、额外遗物、基础遗物和蓝钥匙。首领三件遗物也同时可见，只取一件。隐藏原有轮播及重复领取按钮。 |
| [RestOption.useOption](https://raw.githubusercontent.com/aeubanks/sts/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/campfire/RestOption.java)、[CampfireSleepEffect.update](https://raw.githubusercontent.com/aeubanks/sts/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/campfire/CampfireSleepEffect.java) | 休息预览真实恢复量，提交后用淡入、图标呼吸、恢复数字及音效反馈，再显示明确结果。保留捕梦网和 Recall 的原有核心分支。 |
| [SmithOption.useOption](https://raw.githubusercontent.com/aeubanks/sts/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/campfire/SmithOption.java) | 进入独立可升级牌网格，每页两排共十二槽；选择后展示升级前后 1.5 倍牌面；“重新选牌”返回网格，确认后播放锻造反馈。 |

开箱“两次晃动→爆开→奖励出现”按用户本轮要求强化，不冒充上游已有演出：蓄力 0.36 秒、爆开 0.16 秒、奖励显现 0.4 秒并每行错开 0.07 秒。打开音效在爆开时响一次。休息反馈 1.2 秒，锻造反馈 0.9 秒。全部参数读取共享主题。

核心事务先提交，演出只读结果并短暂阻止房间操作；遮挡、缩放、换房或重开取消时间线，不重复发奖或回血。已有旧控件路径的组件回归保留；正式 GameUI 明确启用新版流程，宿主通关和首领宝箱测试已改为真实列表路径。

商人长对白按二十字符分页，点击或停留后继续，保留全部原文；缩窄底部对话框后不以裁掉对白换取货架空间。

奖励行支持电脑悬停与触屏长按，在左侧显示完整说明；长按后的松手不领取。特价标记移到价格旁，避免盖住卡牌类型与效果。

触屏下未售出的遗物和药水即使金币不足或药水槽已满，仍可点开完整说明；购买确认保持禁用，取消和遮挡会清除只读选择。此路径与可购买商品共用报价所有权检查；桌面点击拒绝购买的原因提示不变。独立审查发现后，以真实触摸按下/抬起/点击顺序复现并补上两项回归，验证只读查看不改变金币、物品或RNG。

## 验证边界

离线预览由真实 Run/Map/Nodes 驱动生成，图库图片用原型字形替代，不能证明原生字体、实际图片或手机手感。生成命令：先 `npm run build:data`、`npm run build:ui`，再 `node scripts/node-ui-preview.mjs .artifacts/shop-source-preview`。

重点回归：`shop_selection.lua`、`node_room_presentation.lua`、`shop_card_identity.lua`、`node_ui_gestures.lua`、`game_ui_boss_treasure.lua`、`game_ui.lua` 和 `node-ui-layout.test.mjs`。新增提取职责纳入现有 15 分支复杂度门禁；历史诊断只在规范化身份集合完全相同后移动位置，没有新豁免。

本次有意替换房间控件与营地流程，完整写序列基线相应更新为 `75180 / 1258450308`；原文字基线 `361 / 1837256485` 不变，旧工程治理取证文件保留原值。宿主测试明确验证休息演出期间拒绝继续、演出后恢复操作；布局测试检查商人文字与商品价格在两个坐标轴上均不交叠。

官方导入、同候选电脑/实体手机实机与 `verify:ui` 仍须独立验收。没有这些证据时三项任务保留未完成。

2026-10-28 用户自行导入修复候选后确认能看出已移植、体验大体可接受，并明确授权合入 develop。这是用户试玩反馈，不补写为自动实机或 verify:ui 通过。合并最新 develop 时同时保留原生卡图绑定/清理、结局与绿钥匙流程，以及其 raycastTarget 原生输入约束。完整记录为 79543 / 1215629804，比 develop 的77278条增加2265条房间流程写入；此前历史抓取与hash原样保留。集成快照冻结历史源文本和当前完整身份，分别检查历史证据与当前代码，不能靠跳过任意差异放行。记录器仅缓存等价行哈希变换，以16位拆分保持精确数值；800步逐字对照及原完整hash验证通过，未提高原30秒期限。
