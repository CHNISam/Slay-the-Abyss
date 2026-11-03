# M9 运行时 UI 工程切片

基线：`aa4d56f57c15727668ef8675e626b44e67a5aaa5`。最终源码身份逐模块记录在 [baseline.json](baseline.json)，换行归一 SHA256；本地工作树版本由该文件标识，不把未提交源码称为基线 commit 的内容。Node `24.18.0`、Fengari CLI `0.1.0`、LuaParse `0.3.1`、固定 SHA256 Luacheck `1.2.0`。执行真实 GameUI/BattleUI/CardView/Run 生产 Lua，原生控件为项目共享 mock。

| 同入口计数 | 原始生产源码 | 当前源码 |
| --- | ---: | ---: |
| 一次 GameUI 战斗 refresh 的 BattleUI render | 2 | 1 |
| 5 张静止手牌，300 次 BattleUI update：位置方法 | 3000 | 0 |
| 同上：尺寸方法 | 1500 | 0 |
| 同上：缩放方法 | 3000 | 0 |
| 三药水，300 次同目标 drag：全部 candidate.prepare | 2100 | 1500 |
| 同上，仅 live run 的 candidate.prepare | 1800 | 1200 |
| 同上：整页 render / damage preview | 300 / 300 | 300 / 300 |

原始计数：[Host](baseline-host.txt)、[药水](baseline-potion.txt)；当前：[Host](current-host.txt)、[药水](current-potion.txt)。`capture.mjs` 从 Git 读取精确基线源码并通过 `package.preload` 装载，不改写生产文件。`capture-red.mjs` 使用原始生产模块分别触发三条新断言，保存 [重复 render RED](red-duplicate.txt)、[静止几何 RED](red-hand.txt)、[药水 RED](red-potion.txt)。不是仅凭命中缓存判断通过。

GameUI 仅在当前 battle 页显式请求 `setActive(..., deferRender=true)`，保留所有 active/suspend/取消输入/原生可见性操作和最后的 `renderBattlePage` 绘制位置；单独 `setActive(true/false)` 仍立即 render。原生 `mapPanel:SetVisible` 内注入真实 `Run.play`，断言最终能量文本读到已提交状态；仅删最后绘制而保留首次绘制的变异必败。避免把最终绘制提前后掩盖中间原生 setter 的重入。

手牌缓存只承诺全部五个方法和两个旋转属性均成功的整组几何，按弱 native box 键、弱 hit 引用与无视图回指的 binding token 隔离。每次先计算八项当前几何；原生 setter 返回 false、抛错、重入或写入期间 pose 改变均撤销承诺，不吞错。动画仍逐帧推进，costHalo 仍走原动画路径。

已审计同一 card box/hit 的其他生产几何 writer：`abyss_battle_card_layout.placeCard`（含 hit 投影）、`placeReward`、`CardView.placeDraggedCard`。`handPose` 在调用 placeCard 前失效，拖动 writer 在写前失效；reward 切换清空手牌姿态，回战斗重新 handPose。resize 走 render/handPose。反馈 flightCard 使用独立 overlay 控件。覆盖外部 layout 覆写后的角度恢复、A→B→A binding 共用 native handle、同名 hit 更换和死亡 native guard；不是对任意未登记的第三方 writer 建立全局拦截。

药水仅把 `prepareMovingPotion` 的 fresh 全库存查询改为已有 fresh 单槽查询；每次仍验证状态，每次仍完整 render 和 fresh damage preview。相同指针/目标/turn 并不能证明 mutable run 不变，故没有跨事件缓存候选或预演。相同对象原地加入 pendingChoice 后拒绝移动，移除后恢复；真实 release 正常使用。此切片减少无关槽位预演，没有宣称已消除重复整页 render/目标预演。

[旧轨迹](baseline-trajectory.txt) 与 [新轨迹](current-trajectory.txt) 的每行完全一致：规则字段、事件数、牌 UID、box/hit 位置/尺寸/比例/旋转；覆盖 hover、return、drag、cancel、resize、覆盖页、卸载/重挂、新战斗和 disable。稳定帧递归检查完整 live run/RNG 图的字段与引用均未变化。

验证：

- [runtime suite](regressions.txt)：14 项，包括 10 个有指定失败断言的错误变异；全部通过。变异覆盖 owner、hit 身份、死亡 native、false、重入、throw 后嵌套承诺、外部 layout writer、重复绘制、最终绘制时序、药水陈旧候选。
- `hand_geometry_cache.lua` 覆盖五种方法分别 false/throw、两个旋转属性部分写入后 throw、嵌套成功/false/throw 的后续重试；失败后不可保留 promise。
- [手牌动效](battle_card_motion.txt) 5 组；[覆盖保留](battle_overlay_surface_retention.txt) 10 次覆盖往返仍创建/销毁 0/0；[覆盖安全](battle_overlay_surface_safety.txt) 覆盖输入、暂停、false/throw、恢复、死亡/终态。
- 原生 startup/UI mock/Grid/Deck Controller/药水 pointer composition 共 13 项相邻 JS 验证通过；四文件最终源码的 startup 另重验。
- [工程门禁](engineering.txt)：320 模块、1853 依赖边；5038/5038 函数/chunk 计量，架构通过，Luacheck 无新诊断。新几何 helper CC 为 1/3/5/11，最长 17 行，见 [函数指标](geometry-functions.json)。全局报告仍为原有 report-only，不把它称为新增收敛门槛。

复现（先构建 data/UI，复用仓库已有依赖）：

```powershell
node docs/evidence/m9-runtime-20261103/capture-red.mjs
node docs/evidence/m9-runtime-20261103/capture.mjs
node --test --test-concurrency=1 tests/runtime-ui-hotpaths.test.mjs
node scripts/check-engineering.mjs
```

官方候选写入/读回、官方导入、当前候选 ready、PC/实体手机性能：全部 **NOT_RUN / UNVERIFIED**。未使用键鼠、未写存档、未推送或合并；独立评审、最终组合树和精确 HEAD 完整托管 CI 由集成者继续完成。TASK-4.21 AC3 不勾选，M9 不能据此宣称手机帧率、加载、内存或全里程碑已达标。
