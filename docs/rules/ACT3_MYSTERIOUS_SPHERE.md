# 神秘球体：阶段与事件战斗请求

本片基线 `3a59d4be`，只实现独立事件组件 `abyss_mysterious_sphere_event`。来源为固定反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方源码或正版PC二进制认证。实际读取本地固定ZIP，整包摘要和9个相关原始成员摘要保存在 `tests/fixtures/mysterious-sphere-source.json`。

## 固定行为与职责

| 来源方法 | 合同 |
|---|---|
| MysteriousSphere 构造、MonsterHelper | 立即构造 `2 Orb Walkers`，不能误用名为 `Mysterious Sphere` 的形状混合组。每台 Orb Walker 的super参数及setHp各抽一次90–96，共4次HP抽样；即便离开也已经消费。实际HP构造由共享桥负责。 |
| INTRO | 打开只进入战前确认，不抽金币；离开先进入END，下一次离开才openMap。 |
| PRE_COMBAT | 普通A0按 `miscRng.random(45,55)` 取包含两端的金币，再取screenless稀有遗物，最后enterCombat。Daily的0–50分支不属于本组件支持范围。 |
| returnRandomScreenlessRelic | 共用稀有遗物队列前端，canSpawn失败走尾端；没有额外稀有度抽样，稀有池空回退Circlet。排除三种瓶装遗物与磨刀石，不能按本地已实现内容缩池。 |
| AbstractRoom、CombatRewardScreen | 预置金币/稀有遗物不立即获得。金币走RewardItem加成。EventRoom不会额外给普通怪/精英金币或精英遗物，不触发Black Star与Prayer Wheel的怪物房分支；通用药水、卡牌奖励仍执行。没有本事件专属战后回调。 |

## 组件接口

`prepare(run,event)` 仅写 `constructorEncounter='2 Orb Walkers'`、intro阶段和文案，不抽随机流。主线程在同一入房事务中调用共享 `Run.prepareEventEncounter`，把真实HP与构造owner保存为 `event.preparedCombat`。

`options(run,event)` 返回intro的open/leave、战前fight、END的leave。`choose(run,flow,choice,uid)` 拒绝非第三幕、错事件、错阶段、非法选项和任何多余UID。fight只消费一次真实房间misc流，写入 `{sourceEncounter='2 Orb Walkers',roomClass='event',gold=roll,relicTier='rare'}`，stage改为combat后返回 `true,'event_combat'`。后续重复fight被拒绝，不重抽金币；不消费遗物队列，不改run.phase或玩家金钱、生命与遗物。

共享层必须在外层 `Run.transaction` 内处理真实构造、screenless稀有遗物预置、战斗准入、失败回滚及完整奖励/节点完成。组件中的preparedCombat测试标记只是边界占位，不证明这些共享行为已经实现。

## 实施与验证

执行计划：先固定来源/接口，添加纯组件回归并确认缺模块RED；再实现最小阶段模块，确认GREEN；最后核对来源和边界文档。主线程负责Backlog、公共接线、架构分类及组合验收，本片不改共享文件。

本片TDD：缺模块RED 126.585毫秒；GREEN 361.017毫秒，原每份Lua30秒预算未提高。六组覆盖纯初始化/只读选项、初始离开两步、三个金币向量和拒绝输入。seed6/8/26分别得到45/50/55金币，核对完整RNG words与counter；向量另由既有独立Python整数模型复算，不从生产Lua取预期。整个组件测试无Run/Map/Combat构造。

命令：`node --test --test-concurrency=1 tests/mysterious-sphere.test.mjs tests/mysterious-sphere-source.test.mjs`。来源锁及独立向量也可单独验证，避免占用重型Lua窗口。

当前只交付组件。未完成Act3自然池接线、共享事件战斗桥、真实双敌构造/战后奖励/事务回滚组合验证；没有新GIL、官方导入、平台启动、实机或UI验收，不计完整事件或M3通过。没有前台、鼠标键盘或受限免费模型调用。
