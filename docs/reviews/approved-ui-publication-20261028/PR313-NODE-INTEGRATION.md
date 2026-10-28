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
