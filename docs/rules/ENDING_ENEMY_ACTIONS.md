# 终幕敌人生命周期与动作接线

本切片把固定初代 PC A0 Heart、Shield、Spear 组件接到真实 Combat 的目录、预战斗、AI 与现有敌人行动队列。来源 member、SHA、独立组件向量分别见 `tests/fixtures/heart-source.json`、`tests/fixtures/spire-pair-source.json`。本切片不负责 Run 终幕可达性、玩家转向或原生平台验收。

`abyss_act4_enemies` 注册三名敌人与状态，沿原构造路径各消费一次固定生命抽样；初始化仍在全组构造之后，预战斗仍在开场洗牌之后。私有意图通过逐字段对照批准的来源定义验收，不扩大 `abyss_effects` 通用操作白名单。Heart 的无敌 300 在死亡律动 1 之前应用；盾矛按源顺序初始化包围、人工制品与背刺身份。

`abyss_ending_actions.plan(Combat,state,enemy,intent,aiRandom)` 在 takeTurn 构造时返回数据计划。Combat 将每份计划排为原有 `enemyAction(stage='ending')`；由 `resolve(Combat,state,payload,enemy)` 执行。它不另开队列、不中途 drain，也不重新排 owner-end 或 RollMove。不是终幕敌人时返回 nil，保留原普通路径。

盾 Bash 的 orb 槽条件与 Boolean 在任何伤害／反伤之前决定；空槽位计数为正仍会抽 Boolean。Smash 的增益格挡使用构造时冻结的普通伤害再经源实际背刺取整后的数值，之后力量、虚弱、易伤变化都不能重算它。Spear 的两张未升级 Burn 只进弃牌堆，不调用卡牌随机流。

Heart 的三减益和五状态按来源顺序排入现有队列；每张状态在执行时独立构造并插入抽牌堆，使用 cardRandomRng 的 0..size-1 位置，空堆第一张不抽随机。状态忽略 Master Reality 升级。强化的负力量补偿与次数在计划构造时冻结，痛苦之刺保持源值 -1；共享 Actor 必须支持该永久身份。

计划里的普通伤害通过既有 `Combat.damage` 执行，不重新实现受伤或反伤。盾矛计划已经应用实际背刺倍率，传入 `normalAmount`；`Actors.attackAmount` 必须保持普通伤害语义。共享 Actor 仅在没有冻结 `normalAmount` 的普通攻击路径另算实际背刺；意图预测遵循来源独立取整边界，不能直接复用实际伤害的末端倍率。

`Ending.retained` 只保留 Damage 与 GainBlock；胜利清场后其余计划和 RollMove 清除。有伙伴存活时，反伤杀死攻击者不会取消已经排好的 ApplyPower、临时牌和 RollMove。共用 AI afterAction 不增加死者过滤；通过 Combat 现有 roll 阶段消费唯一一次 source primary／条件 Boolean。

## 证据边界

`tests/lua/ending_enemy_runtime.lua` 通过真实 `Combat.new`、预战斗和 `Combat.endTurn` 检查 native／advanced 两种回合主机。测试控制 intent ID、无玩家抽牌以及高玩家生命，以隔离动作队列，不是自然通关证据。十组验证范围包括 Heart 前四轮、五张状态两种初始抽牌堆、来源 RNG、Bash 反伤死亡后选招、Smash 快照、Spear 弃牌目标和私有意图拒绝篡改；另以来源独立向量核对盾矛零球槽和空三球槽各六轮的真实选招与完整 AI 流。单独控制到 Heart 第三次强化，使用真实行动器验证负力量修复和源 -1 痛苦之刺身份，不声称自然玩过此前十回合。

Invincible 实际伤害封顶、死亡律动 afterUse／致命牌留存、负值痛苦之刺触发／显示、包围转向／死亡清理与第四幕 Run/Nodes/Host 接入由其他切片负责，必须各自有真实集成证据。本组件测试没有让玩家攻击／用牌来假造这些尚未接入的边界通过。测试沿用默认每份 30 秒预算。
