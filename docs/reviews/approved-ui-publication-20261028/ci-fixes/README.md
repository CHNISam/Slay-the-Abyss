# PR313 首轮Full发现的旧live夹具/历史接层修复

诊断head为4211b4e，Quality40733299999；本页不是修后全量通过声明。

## 真实失败与最小迁移

- Windows rules4：m3_ui_polish:22旧行布局期望失败。Main.dc.html:272–276明确zone1010..1850、front=min190/round(slot*1.1)、300/180前后排、0.86；82–94为58意图高与16间隔。仅改独立expected公式，1e-8局部浮点容差；1..5、seed11、14 aim点、目标身份、回手取消和规则不变断言保留。原source精确字节对当前源RED，修后连同4个Main单元入口6/6 GREEN。
- Windows rules3：card_feedback的body_slam/anger两项落点仍锁旧xTo/y。按Main原文两槽第二列/后排计算expected，10/10 GREEN；全部44个eq保留。
- 相邻live源码逐项短跑先红后绿：shockwave 2/2（area x中心、first actor y）、summon5/5（liveCount和screenSlot独立源公式，输入走真实box.y）。summon鲜活portrait按当前批准行为先显示该actor详情，走真实hit.click关闭再测独立intent；旧触点拒绝、目标真实index、反馈/死体回收不删。
- card_preview原19组/130个eq/7个rgb全部保留，19/19 GREEN、17.02s，原30s预算不变。坐标只作为输入点改为当前可见敌人原生控件中心；原数值oracle仍来自独立Combat结算。当前Details A将尚未执行意图与状态并列，test-only读取器按真实section标题与y归属读取全部buff/debuff，并经真实page.click遍历所有页；不截断状态，不修改运行时。无状态敌人另要求当前意图仍显示。
- 负数小角标：冻结Main实现abyss_battle_unit_view:102使用U+2212，与已有approved_main_unit的−123回归一致；Main.dc.html:256/297也使用该minus字形。HTML没有负状态stack示例，不把它说成HTML明确规定；仅将此控件的“-1”字节期望迁为“−1”，状态文案“力量 -1”和所有数值不改。
- 不足能量费用色：Card.dc.html:149为up=#EF7672，Theme.cardSkin.costTone.up已冻结，card_skin:67处理不足能量；仅将旧danger期望迁为此批准token，数值颜色/规则不改。
- POSIX1：formal-campaign-entry:76与presentation-m3-integration:160直接调用preRetirementSource，最前competition整源hash先拒绝当前Main game_ui。现在仅当完整hash等于既有approvedUi.after时先精确逆向，再执行原competition/formal/retirement守卫；2/2 GREEN。额外明确负控拒绝无关新增、部分UI逆向、部分competition逆向；完整当前源与精确53fa中间源才恢复原retirement字节。

## 保全与边界

`assertion-migration.json`由luaparse按字节range提取原assert/eq/rgb/colour调用：322个旧调用中311个源码逐字保留，11个改动仅为上述几何/字形/token/无状态意图约定；另加5个可见输入/翻页/正确actor详情断言。这个机械核对不自证行为，真实日志分列。

support/battle_ui_cases为58源绑定历史53组；它剩余area x中心仍与Main等价，未改其源码/hash。原26源gzip为6f74bc575b24e5c830119e0309b0311017cbeba5ad5cc6d1fdcc44f69a27e164、原runner与全部budget/golden不改。未改生产Lua/主题/构建，不把旧head CI失败追认为通过。

发现develop已合PR310（432eebb，17:24:41），与本候选Node/静态/历史层重叠。先保全本地修复提交，再由本线程按新职责合流，不整文件覆盖。后续组合须重新验证；PR311仍未合，不主动引入。官方导入/ready/同候选PC手机UI性能仍未测。
