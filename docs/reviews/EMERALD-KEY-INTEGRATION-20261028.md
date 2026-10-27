# 绿钥匙受控纵切与验收边界

TASK-64；本片基于父集成`92440f31a0b526215223a087f393844bf7006e8c`的真实Combat强化/通用怪物再生接口，沿用[源组件](../rules/EMERALD_ELITE.md)和[地图所有权协议](../rules/EMERALD_MAP.md)。没有修改Map、Actor、EnemyAI、Combat、Effects、CardActions、工程配置或Backlog。

Run在Host读取EndingHistory之后、生成地图之前冻结`mapBirthContext`及对应`mapBirthAct`；同幕getter返回副本，重复冻结不能改写，进入新幕才按当前资格和钥匙生成新快照。Nodes恢复只接受该可信出生快照；拿钥匙后仍用本幕最初的`emeraldOwned=false`恢复旧图，下一幕才不再生成燃烧精英。

真实Nodes事务先为合法燃烧节点准备包装，只把`boost.effect`传给Run/Combat；父接口在全部怪物预战斗之后、首次抽牌之前应用强化。成功Map.choose后才commit一次mapRng，并绑定同一runSeed、章节、节点、地图签名、来源遭遇和combatGeneration。构造或Map提交失败不发布Run/地图/RNG。普通战斗、事件、逃跑或下一房间清除旧战斗owner，不能靠显式敌人ID得到钥匙。

胜利的精英遗物组之后建立独立EMERALD_KEY奖励；`Run.claimEmeraldKey`在原Run事务内验证真实flow、battle、出生资格和source owner，再设置钥匙。金币、基础遗物、Black Star额外遗物、药水、卡牌分别领取；绿钥匙没有relicLink。烟雾/失败不授钥匙。离开奖励、同owner重开、下一房间过期、重复领取及旧指针手势均保留原语义，Skip仍只关闭选牌页。

界面沿PR19批准稿与主题：燃烧精英保留原精英图标，并用主题positive绿及“绿钥匙”文字共同标识，地图底部解释真实奖励。只有五至六条独立奖励时扩大原奖励列表面板，原四行布局不变；按钮保持64高及批准字号，六行、说明和继续均在手机安全区内，每层控件不超过60。此差异源于钥匙及Black Star多奖励的必要信息容量，不是新视觉方向；严格生成mock已验证，本轮没有原生截图、verify:ui通过或实机资格。

## 已有证据

- 预写真实Run/Nodes fixture先RED（缺mapBirth边界817ms），实现后六组GREEN 6.837秒：真实Combat.apply一次、源mapRng推进、构造/晚期Map故障回滚、独立领取、失败原子性、离开重开和下一房间失效、Smoke/defeat拒绝。
- 生成控制先RED（缺实际钥匙按钮），实现后静态通过：原生控件种类、可聚焦按钮、命名文字、64高六行、安全区和每层容量。另有13项既有布局/主题静态检查通过，包含原四行奖励布局。
- 严格生成Host UI三组最终GREEN 6.154秒，Node两项通过：六行逐项领取、双遗物与钥匙独立、真实卡牌加入、继续、控制器焦点、替换offer后旧Down/Up/Click拒绝、重开及下一房间失效。
- UI fixture真实失败保留：漏CursorDrag使现有能力门禁进入C档（2.721秒）；误把PC Skip当成放弃卡牌（2.889秒，随后2.761秒定位同一断言）；已观察Down后使用ownerless卡牌Click被正确拒绝（2.916秒）。只修测试输入和既有规则预期，未放松产品守卫，最终用真实控制器确认领取卡牌。
- 两个新增模块的固定Luacheck无诊断；BattleUI、MapUI仅既有shadow/unused self诊断行位移动，配置及诊断豁免未改。最终组合架构分类、精确基线对齐和CI由父集成执行。

所有fixture明确构造既有历史资格、跳过此前房间的导航及晚期剩余遗物队列，并将敌人HP设零隔离胜利边界；**不是自然路线、原版PC运行或平台验收证据**。当前生产数据尚无Black Star定义，双遗物用例额外提供受控持有定义，仅验证真实source队列/Run掉落和UI独立领取，不能算其自然获取或完整遗物池已齐。本片不增加该定义，不宣称M3或TASK-64整项完成。
