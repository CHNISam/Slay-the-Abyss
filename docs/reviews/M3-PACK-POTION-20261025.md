# M3资料包接入：药水旧目标确认的事务边界

归属 TASK-14.1（实际效果与库存事务）、TASK-47（逐项生产/平台证据）。用户于2026-10-25明确要求本资料包作为M3冲刺一环。没有新建研究里程碑，没有改变版本号、合并或发布。

## 固定输入与范围校准

- 用户资料包：`C:/Users/Administrator/Downloads/STA_Reverse_Engineering_Pack_20261025.zip`；SHA256 `9bc126d7eb0958b3d4b5aaf5e311d90294d62edc85a103cd4e46c4334f464490`。
- 先读 `00-START-HERE.md`、`10-project/00-INDEX.md`，再按总索引读基线冲突、M3任务映射与版本收口；仅为本片展开 `30-contracts/potions-and-targeting.md` 和 `40-verification/cases.json` 的 POTION 条目、`90-sources/source-lock.json`。没有加载未来联机/职业/章节模块或全量上游资料。
- 包快照 `35fc111`；本轮已fetch核对的 develop 为 `3ed8bf4b88a950c4736ec2d68e83f141d415c4db`。M0–M2历史验收保留，主关口仍M3。现有发布目标沿用 TASK-20 的 v0.1.0；不推断M3对应新版本号。
- 最新 SCOPE 已批准完整首发涉及内容池和第一幕完整事件池；30张仅是当前已接线集，不能作为完整承诺集或M3验收标准。完整目录继续使用已有 `data/reference/sts1-card-pools/`、`data/catalogs/` 与 launch-content，不新建一套目录系统。
- TASK-47的AC1已通过Backlog CLI移除旧“至少30张”口径，明确完整清单与分层登记；原有其余4项验收要求及未勾状态保留。任务附件增加范围覆盖说明，旧记录不冒充当前要求。
- **代际待明确**：资料包记录用户近期强调STS2，而当前最新SCOPE与AGENTS仍为STS1 PC/A0/单人/全解锁Ironclad第一幕。包内STS2游戏版本、build ID、binary hash均空；已有STS1来源是声明2.3.4的固定社区镜像，也未经正版二进制认证。本轮已向用户列出两种选择并请求二代构建信息。未收到选择前，不改代际敏感数据，不把两代同名牌当作同机制。

本片只检验已批准交互的拒绝/取消事务，不新增伤害、费用、AI、池或概率规则。包是行为规格来源；原作数值来源继续保留在 `data/SOURCES.md` 和已有药水账本中。

## 输入、动作与期望

测试文件：`tests/lua/potion_target_rejection.lua`，使用既有真实host夹具。库存通过生产 `Run.discardPotion/obtainPotion` 准备；这是测试准备，**不是自然掉落或购买取证**。

| 对应规格 | 输入与动作 | 期望 |
| --- | --- | --- |
| POTION-02 | 两敌，选单敌药水，敌人B Down/Up；确认Click前使B死亡、替换为同值新actor或交换A/B；中间不重绘 | 拒绝旧确认，所有run值不变，不打到A或新actor |
| POTION-05的使用侧实例边界 | 同上，确认前实际丢弃再取得同ID新瓶；不重绘 | 新瓶不继承旧瓶的目标确认，不消耗新瓶 |
| POTION-04的阶段拒绝子集 | 同上，确认前改变turn或run.phase；不重绘 | 不消耗、不伤害、不新增事件、不消费RNG |
| POTION-03 | 敌人B Down/Up后取消药水，再次选药水，再送旧Click | 旧确认不生效；随后新的B手势能成功，A不受影响，瓶仅消费一次 |

每个拒绝例比较整个run值，包括战斗、事件、永久牌组、奖励、库存和各随机状态；只排除静态data与host计时elapsedSeconds。未比较对象地址保持；数值相同的对象替换不因此认证身份不变。POTION-05的满槽购买/金币和旧丢弃回调由既有 `game_ui_potion_discard.lua` 继续负责，本新增文件不冒称覆盖整条满槽自然获取链。

## 生产接线与回归责任

实际链路为 `abyss_game_ui` 组合的 `abyss_battle_ui` 药水/敌人监听器 → `potionReady/aimReady/enemyReady` → `commitPotion` → `Run.usePotion` → `Inventory.apply`。新增测试不复制分派器或算法；旧确认被生产校验拒绝。现有实现已满足这7例，没有证红缺陷，因此不为制造修改而改生产源码。

新文件由 `scripts/test-lua.mjs` 目录发现，随现有 `npm run test:lua` 进入Quality；`data/release/launch-content.json` 的potions profile登记它，平台与自然实机状态继续pending。没有将manifest变成运行时放行框架。

## 本轮证据与剩余责任

- 本地：新增7/7通过；独立子代理只读复核并复跑7/7，无确认P1/P2。既有 `potion_targeting.lua` 5/5、`potion_targeting_commit.lua` 4/4、`potion_target_input_ownership.lua` 7/7、`game_ui_potion_discard.lua` 10/10通过，共33组Lua（不重复计独立复跑）。现有清单CLI、13项Node清单测试和 `npm run verify:backlog` 通过，`git diff --check` 无错误。后三个Lua原始输出在本工作树 `.artifacts/pack-validation/`。未运行全量 `npm run check`，不称全量检查通过。首次普通沙箱阻止Node/Python子进程（EPERM）；经沙箱提升后原命令通过，不归因游戏缺陷。
- 候选构建及独立读回通过：运行时固定源 `3ed8bf4b88a950c4736ec2d68e83f141d415c4db`，副本为本工作树 `.artifacts/m3-pack-candidate-3ed8bf4/normal-build/wmvn5h3ef-0/working.gil`，2815156字节，SHA256 `f2808674cca47de5aade4871fc0da82fdd9d25c801e6cc7d31ec4cd0400bdf68`。主线程独立读取build/audit与文件hash核对：61模块全部匹配固定源，UI2824/max60，结算图22节点，静态0错误/33警告；警告原样保留。图审计仅认证身份、服务端类型、非空载荷、监控信号和启用挂载，不认证编译节点参数或运行语义；未额外宣称完整图payload审计通过。`MILIASTRA_ALLOW_LIVE_WRITE=0`，正式存档未写。本轮没有复用9ae候选截图认证3ed源码。摘要见[结构化证据](../evidence/m3-pack-potion-20261025.json)，原始 `receipt.json` 与 `source-audit/audit.json` 保留在本工作树上述artifact目录。测试/清单/任务文字的后续提交不改变该运行时固定源。
- 官方导入：未验证。
- 同候选真实试玩：未验证。待官方新存档导入、源码读回、本轮ready与clientScriptLog=true日志后，按POTION-02/03/05对应可触发路径取证；自然来源与满槽金币由TASK-14.1/52负责，逐项登记由TASK-47负责。
- 完整药水池、逐项数值、原作构建真实性及全内容自然获取并未因本片通过。TASK-14.1/47和M3保持未验收。
