# M3事件与道具生产集成

本批合并前冻结记录：在最新develop518299c的新执行树中整合六个已冻结来源，按TASK-13.1.2事件→TASK-14.1药水→TASK-14.1遗物→TASK-47主集成串行领取。主线程唯一写入；六源树、旧M2及工程树和暂存区只读保留。当前仅初代PC A0，完整75战士卡（3基础+72非基础）与25事件的验收要求不变；版本0.1.0，不发布。

固定来源为aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0（镜像声明V2.3.4），ZIP SHA256 3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458；不是认证PC二进制或本轮原作实测。资料包ZIP SHA256 9bc126d7eb0958b3d4b5aaf5e311d90294d62edc85a103cd4e46c4334f464490。复用data/SOURCES.md、launch-content和现有Lua/Node/千星工具链，不提交反编译源码。

| 切片及生产入口 | 输入、顺序、期望输出 | 本地检查 | 候选 | 官方导入 | 同候选真实试玩 |
| --- | --- | --- | --- | --- | --- |
| 事件：Nodes/EventPool/NodeUI、永久Run事务 | 四事件经正式选项/UID选牌器完成；Big Fish先遗物后诅咒，Bonfire先奖励后移牌；Fountain逆序UID清除十种基本诅咒，Parasite移除减3最大生命且下限1 | 事件/原生UI/永久事务69项通过；卡面保留原51–60并新增81–89的38个基本/升级显示 | 见下方冻结候选记录 | 未验证 | 未验证 |
| 药水：Run.usePotion、真实战斗/选牌/背包UI | 初始药水动作→Toy回血→抽牌及BOT；Chaos承担Pain/Normality，Smoke回图无奖励；Belt槽4/5说明、使用、丢弃、原槽补回；自动攻击后立即逃跑，下战保留遗物计数 | 20份Lua专项105项通过，含Chaos→Smoke→下战真实Run红绿 | 见下方冻结候选记录 | 未验证 | 未验证 |
| 遗物与永久钩子：RelicHooks/Inventory/Run/Nodes | Maw在未知转类前、Meal/Tea在实际房型后；Dream Catcher真实三选一；商店先扣金/onSpend后onRemove；瓶装清除资格与所有原生选牌器一致，失败回滚 | 13份遗物/诅咒专项通过；inventory11项经稳定ID修复通过 | 见下方冻结候选记录 | 未验证 | 未验证 |

共享事务只复制一次完整可变状态图、保留跨字段别名；嵌套拒绝会使外层失败，实体onObtain在永久入组前执行，异常不消费UID/金币/RNG。新增permanent_purge_routes七项回归覆盖商店/Cleric/Purifier/Golden Wing及瓶装过滤。

补查旧奖励UI时，battle_ui_potion_rewards原断言复现卡牌领取替换整份reward owner的问题。保留该旧测试，限定claimCardReward在私有事务成功后仅将cardResolved写回原奖励owner；独立potion/cards/stolenGold对象保持原身份，失败不触碰原对象。permanent_transactions新增钩子异常、整体回滚、成功保留子owner及卡牌/药水/金币仅领一次回归，现13项通过。此生产修复已重建并独立审计，后续纳入develop已批准的PR207布局后再生成下方RC2；cf77与4d9f候选均作为历史保留。

本次整合保留develop刚合入的完整72非基础真实胜利→公开领奖→下一战同UID回归（20common/36uncommon/16rare；稀有来自合法第二次奖励）、3基础渠道、目标失效与奖励原子性断言及既有独立分片/时限。显式遭遇回放不是自然地图或平台验收。没有改池、重抽、降低敌HP或RNG注入来制造该奖励覆盖。

独立只读复审抓到并修复：非致死Chaos自动出牌后Run未提交relicCounters，立即Smoke会让Pen Nib/Nunchaku下战倒退；新增正常HP Cultist三次攻击回归先红后绿。严格生成UI树还证红根层试探查询potion4，改按实际子容器路由后38个卡面通过6254ms。库存旧断言把数组首项当火瓶，改按fire_potion稳定ID保留原20点/隔离断言；原失败日志保留。

本轮本地原始日志：build/m3-events-local.log（末项先红）、build/m3-potions-local.log、build/m3-relics-local.log（inventory旧索引先红）、build/m3-inventory-green.log、build/potion-counter-red.log、build/m3-integration-local.log。完整仓库检查交本PR当前SHA CI；历史1241pass/119skip及36份Lua只属于旧冻结树，不当当前整套通过证据。最终CI与实际合并以GitHub本PR当前头和合并记录为准，不预写成功。

剩余M3缺口：本批42遗物含33common和3special，但完整130目录不等于效果齐备；药水28定义中27战士，21种新增战士药水仍acquisitionPending，33项完整采样器未接自然获取，另6种战士效果未齐；默认七事件仍未切完整25池，六个显式新增事件不代表自然遇到；Spirit Poop持有已接，-1分函数尚无生产总分消费者。专属special图标仍为明确占位。不得因此删池/重分概率或将父任务、M3标Done。平台逐项验收归TASK-13.1.2/14.1/47，概率与自然路线归TASK-12.5；同候选整体UI须另过verify:ui门禁。

冻结候选记录：合入develop PR207（c1cb78e）的已批准移动端布局后，按同一固定基线重建完整含BGM候选。稳定归档.artifacts/m3-events-inventory-20261025/candidate-rc2/audio/wmvnm0z6z-0/working.gil，SHA256 8c8f04612f6c1858b5146fb2355eda020e3fcf342f897d1e187d88f0a2097ce0。audit-native-candidate对实际生产提交3e9873220cf5aa055799992c906ade0daf167f63独立读回，71模块逐字节相同，issues为空；候选hash前后不变。静态0错误/36警告原样保留，不当平台通过；原始记录归档audit-rc2，文档头1647330已以audit-delivery读回；固定CI运行时后的最终头再以audit-runtime读回同一候选。官方导入、同候选真实试玩、BGM听测和UI总门禁均未验证；本轮没有桌面输入窗口，只做离线工作。

补充本地证据：25项Node来源契约全过；178卡面通过；奖励永久事务13项通过；十组上游药水/领奖/商店/事件回归完成。中途远端TLS续租失败使受控子进程停止，保留中断记录后仅恢复剩余shop/unknown_events，不声称单次完整运行通过。用户最新要求已写入AGENTS及P0-SMOKE：任何可能抢焦点或鼠标键盘的操作都先约明确窗口，子代理同样受约束。

上游完整卡面回归仍将总数固定160，新增九张诅咒后实际应为89定义/178个基本及升级版本；已复现旧计数断言失败。修复只将总数与说明更新为178，保留原有逐卡全名、正文、字号、动态数值与双增益断言，不删除原160版本或放宽文字布局。库存连续战斗夹具明确标为旧六起始遗物隔离回归，不冒称完整遗物自然获取。

完整CI失败与修复记录：e1fd024的Quality40174178038第一次在potion_basic_five原30000ms预算超时（JS1265通过/1失败/119跳过）；同源独立重跑13817ms通过。仅重试一次完整CI，Node全通过，但全量Lua暴露七份旧oracle：数组首项当火瓶、12药水白名单、开局参考漏新增遗物字段、成功事务仍比较旧RNG owner/旧卡牌表和旧空牌提示。逐项按当前公开契约校准，保留失败时owner不变、原RNG状态、完整75渠道、同UID升级/下战、旧UI行为及全部分片与原时限，未改卡池或skip。校准后17个Lua入口和12个Node布局用例本地全过，日志build/m3-calibrated-regressions.log。新头须重新通过完整CI，旧两次失败日志保留，不冒充全套成功。

CI运行时修复：1647330的Quality40179995339在本机slay-the-abyss-windows/Node22.22.1运行，Node1387项中1268通过/119既有跳过/0失败，数据校验通过；全Lua仅完成到tests/lua/potion_status_rules.lua，battle_ui、card_help_release、living_wall分别在原60/30/30秒超时，最终被GitHub45分钟整作业上限取消。此前同生产源在STA-Sister-Win/Node24.18.0较快，该运行器当前离线，不能把两机差异直接归因源码。已下载Node官方24.18.0便携二进制并核验官方SHA256，同机、不改源码与任何断言/时限重测三份，分别18267/20229/48674ms全通过；原始日志build/m3-node24-*.log。Quality仅固定此已验证运行时，系统/MCP Node不动，整套45分钟及每份30/60秒上限仍原样，未拆走、减少或跳过用例。候选生产71模块未变，不重建另一份冒充；最终头独立审计保存audit-runtime，新的完整CI结果仍须实际全绿后合并。

2026-10-25变异检查修复：5773691的Quality40204188489已完成全部JS、Lua及静态检查，但工程末项的M3/M4在正常基线阶段超时。完整inventory与node_transactions在该CI分别耗时22766/19569ms，变异器每次调用仅允许15000ms，尚未执行变异便失败。本轮原生移交后先补三项回归真实失败，再为变异调用显式传入原用例名；两个Lua测试仅在收到该显式参数时选择唯一用例，未知或重复选择必须报错。正常全量入口不传选择器，仍执行全部12/11项，所有原断言保留。每次15000ms及整轮120000ms预算未变；四个真实变异均由登记断言检出，局部耗时2285/1482/1450/1763ms，证据build/test-strength/900c0d2f-6cca-4560-9900-8eea78f31e8c/report.json。当前提交完整CI仍须重新实际通过；本轮不改游戏生产Lua、候选或平台验收状态。

2026-10-26附件首个生产修复：对照固定aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0的actions/unique/GainBlockRandomMonsterAction.java/update，护盾地精保护目标必须消费aiRng，原Effects在正式roomStreams路径仍误用legacy LCG。保留gremlin_gang原18组，新增第19组正式房间状态回归先报“AI计数应4实3”，再将目标选择接入既有abyss_enemy_random.integer；无aiRng的历史显式入口仍沿用其原回调。独立Python整数模型（既有tests/fixtures/sts-random-wrapper-source-vectors.json生成器）给出room seed42的后续0..99抽样：保护前88，非空目标抽取后61；单目标也推进一次，无目标自保不抽样，同时核对HP/洗牌/卡牌流快照与legacy种子未改变。gremlin_gang19组及原shield_gremlin22组通过，架构66模块/199边通过，Luacheck仍仅114条历史诊断、无新增。原始红绿日志build/shield-rng-red.log和build/shield-rng-green.log。

此后Effects生产源码已改变，先前RC2和其71模块审计只代表原冻结源，不能认证本次组合。本片尚未重建新候选、官方导入或实机验证。附件的四职业300牌、完整Neow、23敌逐方法整体验收仍未完成，不因该单项修复宣称齐备；最终组合CI必须按最新SHA重新通过。
