# M3事件与道具生产集成

本批合并前冻结记录：在最新develop518299c的新执行树中整合六个已冻结来源，按TASK-13.1.2事件→TASK-14.1药水→TASK-14.1遗物→TASK-47主集成串行领取。主线程唯一写入；六源树、旧M2及工程树和暂存区只读保留。当前仅初代PC A0，完整75战士卡（3基础+72非基础）与25事件的验收要求不变；版本0.1.0，不发布。

固定来源为aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0（镜像声明V2.3.4），ZIP SHA256 3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458；不是认证PC二进制或本轮原作实测。资料包ZIP SHA256 9bc126d7eb0958b3d4b5aaf5e311d90294d62edc85a103cd4e46c4334f464490。复用data/SOURCES.md、launch-content和现有Lua/Node/千星工具链，不提交反编译源码。

| 切片及生产入口 | 输入、顺序、期望输出 | 本地检查 | 候选 | 官方导入 | 同候选真实试玩 |
| --- | --- | --- | --- | --- | --- |
| 事件：Nodes/EventPool/NodeUI、永久Run事务 | 四事件经正式选项/UID选牌器完成；Big Fish先遗物后诅咒，Bonfire先奖励后移牌；Fountain逆序UID清除十种基本诅咒，Parasite移除减3最大生命且下限1 | 事件/原生UI/永久事务69项通过；卡面保留原51–60并新增81–89的38个基本/升级显示 | 见下方冻结候选记录 | 未验证 | 未验证 |
| 药水：Run.usePotion、真实战斗/选牌/背包UI | 初始药水动作→Toy回血→抽牌及BOT；Chaos承担Pain/Normality，Smoke回图无奖励；Belt槽4/5说明、使用、丢弃、原槽补回；自动攻击后立即逃跑，下战保留遗物计数 | 20份Lua专项105项通过，含Chaos→Smoke→下战真实Run红绿 | 见下方冻结候选记录 | 未验证 | 未验证 |
| 遗物与永久钩子：RelicHooks/Inventory/Run/Nodes | Maw在未知转类前、Meal/Tea在实际房型后；Dream Catcher真实三选一；商店先扣金/onSpend后onRemove；瓶装清除资格与所有原生选牌器一致，失败回滚 | 13份遗物/诅咒专项通过；inventory11项经稳定ID修复通过 | 见下方冻结候选记录 | 未验证 | 未验证 |

共享事务只复制一次完整可变状态图、保留跨字段别名；嵌套拒绝会使外层失败，实体onObtain在永久入组前执行，异常不消费UID/金币/RNG。新增permanent_purge_routes七项回归覆盖商店/Cleric/Purifier/Golden Wing及瓶装过滤。

补查旧奖励UI时，battle_ui_potion_rewards原断言复现卡牌领取替换整份reward owner的问题。保留该旧测试，限定claimCardReward在私有事务成功后仅将cardResolved写回原奖励owner；独立potion/cards/stolenGold对象保持原身份，失败不触碰原对象。permanent_transactions新增钩子异常、整体回滚、成功保留子owner及卡牌/药水/金币仅领一次回归，现13项通过。此生产修复已重建并独立审计最终候选4d9f3d0a；先前cf77候选仅证明bd93be7，作为历史保留。

本次整合保留develop刚合入的完整72非基础真实胜利→公开领奖→下一战同UID回归（20common/36uncommon/16rare；稀有来自合法第二次奖励）、3基础渠道、目标失效与奖励原子性断言及既有独立分片/时限。显式遭遇回放不是自然地图或平台验收。没有改池、重抽、降低敌HP或RNG注入来制造该奖励覆盖。

独立只读复审抓到并修复：非致死Chaos自动出牌后Run未提交relicCounters，立即Smoke会让Pen Nib/Nunchaku下战倒退；新增正常HP Cultist三次攻击回归先红后绿。严格生成UI树还证红根层试探查询potion4，改按实际子容器路由后38个卡面通过6254ms。库存旧断言把数组首项当火瓶，改按fire_potion稳定ID保留原20点/隔离断言；原失败日志保留。

本轮本地原始日志：build/m3-events-local.log（末项先红）、build/m3-potions-local.log、build/m3-relics-local.log（inventory旧索引先红）、build/m3-inventory-green.log、build/potion-counter-red.log、build/m3-integration-local.log。完整仓库检查交本PR当前SHA CI；历史1241pass/119skip及36份Lua只属于旧冻结树，不当当前整套通过证据。最终CI与实际合并以GitHub本PR当前头和合并记录为准，不预写成功。

剩余M3缺口：本批42遗物含33common和3special，但完整130目录不等于效果齐备；药水28定义中27战士，21种新增战士药水仍acquisitionPending，33项完整采样器未接自然获取，另6种战士效果未齐；默认七事件仍未切完整25池，六个显式新增事件不代表自然遇到；Spirit Poop持有已接，-1分函数尚无生产总分消费者。专属special图标仍为明确占位。不得因此删池/重分概率或将父任务、M3标Done。平台逐项验收归TASK-13.1.2/14.1/47，概率与自然路线归TASK-12.5；同候选整体UI须另过verify:ui门禁。

冻结候选记录：奖励owner修复后，现有build:native已重新生成完整含BGM候选，稳定归档.artifacts/m3-events-inventory-20261025/candidate-final/audio/wmvniiay1-0/working.gil，SHA256 4d9f3d0a0e21e9ea4f7e96eca7adf8ae1eaede4c117ec02aa6022f5e4d8c7f8c。audit-native-candidate对实际生产提交ded810f0f7b403b564bee64df06117587957500f独立读回，71模块逐字节相同，issues为空；候选hash前后不变，原始记录归档audit-reward-fix/audit.json。静态0错误/36警告原样保留，34个自定义控制器方法提示及2个纯模块未挂载已定位，不当平台通过。最终PR提交另以audit-final/audit.json读回同一候选。官方导入、同候选真实试玩、BGM听测和UI总门禁均未验证；本轮没有桌面输入窗口，只做离线工作。

补充本地证据：25项Node来源契约全过；178卡面通过；奖励永久事务13项通过；十组上游药水/领奖/商店/事件回归完成。中途远端TLS续租失败使受控子进程停止，保留中断记录后仅恢复剩余shop/unknown_events，不声称单次完整运行通过。用户最新要求已写入AGENTS及P0-SMOKE：任何可能抢焦点或鼠标键盘的操作都先约明确窗口，子代理同样受约束。

上游完整卡面回归仍将总数固定160，新增九张诅咒后实际应为89定义/178个基本及升级版本；已复现旧计数断言失败。修复只将总数与说明更新为178，保留原有逐卡全名、正文、字号、动态数值与双增益断言，不删除原160版本或放宽文字布局。库存连续战斗夹具明确标为旧六起始遗物隔离回归，不冒称完整遗物自然获取。
