# PR313：接续已合入的 Node UI 拆分

2026-10-28 18:24 UTC。线性接续 develop `432eebb1d51a7ad37cfbc19f0e846bc00f1f4ba7`（PR310）。保留全部 Node 根入口与10个拆分模块；仅将已批准的卡名、正文、遮罩所有权三处视觉职责落在真实 faces 模块。后两项所有权局部值使 frame/fillCard 复杂度维持14，不放宽15门槛。未采纳尚未合入的 PR311/317 内容。

## 历史身份与真实最小修复

- 原58源 JSON、26源 gzip、PR310 archive、三个逐写 golden 和所有 runner/预算均不改。新增两层完整文件 SHA/精确 hunk 逆向：当前 faces → PR310 → 原批准 monolith → 53fa；临时目录写入前核对真实当前根入口、faces 和其余模块，再仅删除历史中确实不存在的10个模块。
- 独立审查补上“历史根入口 + 缺失/漂移 faces”绕过的拒绝路径；负例确认拒绝发生在目标任何写入/删除之前。最终逆向7/7、相关拒绝/卡框8/8；提交前新跑入口、卡框与逆向10/10，历史 Node 负例另1/1。
- 真实输出树暴露三处共享数组别名：blocked pill、deck capsule、potion discard slot。只克隆输出的 size，冻结主题/修改输出不再相互影响；不是删冻结测试。官方已存在 lock 图标100169改用语义 token 检查，覆盖替换值传播，不引入新图标。药水 glow 用原稿精确22/1.5，而非六位截断造成的边界溢出；不放宽容差。
- `card_blocked_display.lua` 原字节移到 support；原来它只在JS注入全局数据后可运行，不能再作为无注入原生独立夹具发现。唯一调用同步更新；原运行内容、断言和runner不变。

## 本轮已读取的实际运行

| 范围 | 真实结果 |
|---|---|
| 原批准旧 monolith 与新 PR310 模块，同一当前依赖、原9个比较fixture/120s预算 | 9/9 完整输出SHA相同；逐项摘要见JSON |
| 原79543 / 79757 / 81392逐写 | 14.910 / 14.704 / 14.563s，原顺序与hash通过 |
| 历史组合整条命令 | 20/21；唯一红为已拒绝漂移后的错误文本缺原regex；补回既有文本后，提交前单项负例重新通过。不伪报整条21/21 |
| 最终原生输出/主题/壳体/边界 | 21/21 |
| 卡值fixture + M3可见槽/实际命中/召唤替换/状态/菜单 | 10/10；UI signed count 保留批准的unicode负号 |
| action compatibility / target rejection | 8/8（13.542s）/ 7/7（12.605s）；完整旧状态hash和stale确认断言保留 |
| 新补读旧CI后去重：ownership / Curl / duplication | 原源真实红；最小补真实菜单Use或关闭详情后，9/9 / 1 / 1绿；m3_ui_polish已修项重跑绿，不算新修 |
| 最终便携门禁 | JS语法、Backlog/network、231模块/1297边、60条明确历史诊断/625责任测量，原复杂度门槛通过 |

新增三处测试迁移经独立只读复核：ownership 仅在三个合法matching Click后追加同触点真实Use事件，foreign/missing/stale/Down-only原始路径及全部断言保留；duplication复制/Strength=4/牌堆/队列全部断言保留；Curl先确认敌人点选不改状态，实际关闭详情后再发新的出牌输入。没有为迎合旧一击消费修改生产代码。

旧head `4211b4e` 的 Full Quality 失败是真实历史，inventory成功。旧失败已去重对应：M3几何、card/shockwave反馈、summon help、card preview、retirement entry guard、Node历史层、数组别名、lock token、glow精度、Unicode负号、JS注入夹具发现与显式药水Use；当前本地定向结果不冒充新head托管全绿。两次本地全量check都中断无终态，不再第三次全量本地重跑；以更新后的精确HEAD完整Hosted Quality/inventory收尾，不跳测试、不升超时、不豁免业务红灯。

原始大输出留隔离云目录 `.artifacts/`，不提交287MiB产物。紧凑证据记录源码hash、日志hash及9项输出hash。既有修改前后图与来源见本目录README及药水纠偏记录。官方导入、本轮ready、设备像素、真实触控/PC手机与性能仍未验证，TASK-4状态/负责人/AC不改。

## 当前托管失败修复：既有冻结主题旁支（19:00 UTC）

`7a4910b` 的新Quality `40745192120` 中，POSIX4成功，POSIX1唯一业务失败为`final-integration-source`明确传入既有冻结主题`f88fac`时，被新outer完整源检查提前拒绝；不是忽略红灯。原始job `123020465946`日志已取回。

先独立验证task77 fixture完整SHA `f5d61e…bee3a`及formal-entry metadata `cb1c426…9893`均与旧`4211b4e`原字节相同；由原historicalGlyphTheme直接得到`f88fac`，按原formal hunks逐行核对、固定位置+10精确逆得`992e36ac`。这两个身份在原formal/retirement合同早已存在，不从失败日志发明白名单。只在`data/presentation/ui_theme.json`路径新增两完整历史身份，重锁新outer整文件SHA，原冻结档案和原数字不改。独立只读系统审查所有可达frozen callers，确认没有其他漏接直接旁支；更早专属层输出不扩进名单。

新回归先在真实outer guard红，再验证完整正链、CRLF、单空格漂移及错误card-face/formal代码路径拒绝；live根入口/faces的写前物化校验未改。相关14+2项、原native主题/图标位置8项、formal纯合同4项及语法/空白通过。仅修测试历史接层；生产、runner、golden、预算不变，不重跑无关的9Node/三逐写大输出。其余当前矩阵仍待终态，之后以修复后的精确head重新跑完整托管Quality；此处不宣称7a4910b或未来head全绿。

rules6唯一红也为同一冻结主题旁支。rules8唯一红为`battle_ui_drag_source`旧oracle：最小探针证明合法输入后的raw坐标`(173.33333333333337,47.333333333333314)`与真实敌人中心reticle`(173.33333333333334,47.333333333333336)`本来就不同；stale输入前后分别逐位不变且target=1不变。迁移为合法输入后先严格断言reticle属于实际enemy1，再严格比较stale前后reticle/target；原gesture坐标、两牌preview、能量/手牌断言保留，新增完整core图引用/数值快照。不放宽容差，另有独立Main原稿公式检查。原10组现16.746s全绿，root已独立读diff认可。

rules1唯一红为`game_ui_class_choices`原30s在最后第10组超时，前9组完整通过；已有19286ms权重，实际独占，不是短夹具池并行竞争。同源本地原30s仍通过10组但26.590s，说明托管余量不足。按既有class_powers方式机械分1–5/6–10，完整原文SHA `69060f92…9b04b` / Gitblob `295f6132…00f7`必须可重建，原body/seed/断言及每片30s不改；最终两片实测5+5通过，分别11.357s/13.425s；CASE1..10依序各一次。纯JS合同先红2/2、后绿2/2，精确重建上述完整原文/Gitblob；raw8片workers1/2、Node通配与win8/linux4计划唯一发现。root独立逐文件读差异及合同，已认可机械分片；该认可不代替新head完整托管CI。

## 可达药水信息路径收口（19:23 UTC）

rules4唯一业务红为`potion_belt_ui`旧逐槽help可见断言。改用真实可见瓶Down/长按0.4/Up/Click查看独立4/5槽详情，逐项锁定真实potionId/标题并实际关闭，再走菜单Use；原3/5容量、管理丢弃/补位、库存/能量、能量+2/Strength2、商店/奖励全部断言不改。root独立读diff认可。最终5组13.206s通过。

同根因系统扫描发现`potion_targeting_help`会向隐藏legacy帮助控件直接送事件而形成假可达正例；先加可见入口断言真实红，再改可见瓶长按，原summary/毒药解释、完整run/battle快照、target、S13/P12均保留，最终3组9.867s通过。扫描确认其余真实输入已补Use，无旧enemyRow坐标用作实时指针；战后potionReward与冻结历史delta oracle不误改。

另三处隐藏compact label覆盖盲点只做同范围加固：`potion_remaining_ui`、`potion_flex_speed_ui`、`potion_sustained_ui`保留全部原存储文案与可信Run.usePotion设置，额外走真实可见瓶长按并检查可见详情效果，持续状态之前实际关闭详情。分别原6/2/3组通过（9.799/3.899/5.034s）。不把存储文字充当玩家可读证据，不恢复旧控件，不删原信息/安全断言。已收齐该扫描后停止扩范围；整个收尾批次没有修改生产、runner、golden或原预算，托管最终head仍待重验。

19:30 UTC旧`7a4910b`完整托管运行已终态，最后rules5/7均成功。已收齐全部失败且仅上述4根因：glyph旁支、Drag旧oracle、class choices超时、belt旧help；其余实测片成功。最终修复批次提交前30项源/历史/发现合同、JS及受影响Lua语法、Backlog/空白通过，生产src/scripts/data与runner相对7a没有改动。正常更新同PR后，必须以新精确HEAD完整Quality/inventory真实结论验收；不复用这次旧head的分片绿灯。
