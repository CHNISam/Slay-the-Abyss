# TASK-100：首份离线运行时路径基线

本切片仅建立可复跑测量入口，不改变生产运行时，也不宣称优化、实机或 TASK-100 完成。依赖 #521 的任务定义，代码提交见 #523。

## 复跑

先执行 `npm run build:data && npm run build:ui`，再运行 `node scripts/benchmark-runtime-path.mjs`。三次独立 Node/Fengari VM，每次最多30秒；不加入普通 Full 的重型回放。定向合同测试为 `node --test tests/runtime-path-baseline.test.mjs`。输出 `build/runtime-path-baseline/report.json`，本次完整来源和逐阶段原始数值保存在[证据](../evidence/runtime-path-baseline-20261106.json)。

工作负载固定 fixture seed=1，并断言实际 runSeed。测量冷 Host 构造、同 VM 第二次构造、开局地图、真实地图入战、完整回合及反馈、完整 Host 静止300帧、卡组打开关闭、奖励创建与返回地图、停用。奖励阶段按既有 Host route fixture 人工设置敌人终态，仅测转换，不代表一场战斗胜利耗时。

每阶段记录 require 调用/首次加载、白名单原生 setter/listener/RefreshItems 调用、属性写入、snapshot capture、墙钟、Node进程RSS/heap。方法内属性写入可与方法计数重叠，不能相加称为引擎调用总数；helper、回调、GetChild/GetChildren 不计入原生方法计数。300帧包含主动待机动画，非零写入不自动意味着浪费。

## 本轮结果及限制

首份基线源码集合摘要 `2be41eea587a7a38b120c3710606385841f3d778e398e51b1966900da9bf3a28`；全部文件逐项摘要及生成 Lua 在证据中，测量前后身份相等。三个样本的五类调用计数逐阶段完全相同，所有生产路径断言通过。P50/P95 为 nearest-rank；n=3 的 P95 就是最大样本，不代表稳定尾延迟。

冷构造包括模块/数据导入；暖构造阶段包括首次 Host 停用，没有强制GC。每阶段计时包含观察器成本，内存为 Node/Fengari 进程而非原生Lua/设备内存。没有无观察器性能校准。三个样本是同版本冷暖配对，不是优化前后配对，尚未证明整体无回退。

独立审查发现并已修复：原生计数混入fixture回调、300帧未走完整Host、观察器丢失cursor能力保护/零参数语义。新增真实Lua微测覆盖白名单、重复属性写入、零参数/nil/方法接收者/返回值、能力及只读保护；另有缺阶段/观察器、非法数据和百分位负例，共4个定向测试通过。verify:backlog、check:guidance、diff检查通过。Backlog CLI 1.53.0 doctor 对其 active/completed 扫描范围返回0；另一路独立递归archive核查发现既存5组跨归档ID碰撞（25.3/25.4/61/64/69），不是doctor报错。本切片不修改这些历史，也不把doctor退出0扩展为全历史唯一性证明。完整CI与合后验证尚待，未重复本地Full。

## 补充复审：证明回合确实执行

首份路径只断言点击后仍在战斗且反馈结束；真实Host的endTurn替换为空操作后，回合不变、combat-turn五类计数全0仍能取得PASS。现在记录点击前的combat对象与turn，结束时要求对象相同、恰好推进一回合、返回player阶段且反馈结束，拒绝把未执行的工作计成加速。新增轻量合同负例覆盖空操作、跳回合、敌方阶段、对象替换、离开战斗和未结束反馈；共5项定向测试通过，普通Full未增加真实Host重型回放。

修复后真实Host正例通过，空endTurn负控按回合断言失败且无PASS。补充[原始三VM证据](../evidence/runtime-path-turn-proof-20261106.json)保留485文件身份，源码摘要 `0e897f68ec5dd5b659af56c21fc620d07c4339d184467c6cb776a6618f115fb4`，逐阶段五类调用计数与首份基线完全相同；wall P50/P95为5.711/5.805秒，只描述这次小样本，不证明性能优化或完整战斗语义。独立复审通过；原始首份证据保持不变，精确CI与实际合后Full仍待。

TASK-100 保持 In Progress，所有 AC 未勾。后续仍需同源优化前后配对、原始静止写入来源归因和无回退解释、独立审查及实际合后Full；官方候选/手机证据保持 UNVERIFIED，交接 TASK-4.21。

## 方法与属性归因切片

基线工具现输出 schemaVersion 2：每阶段新增 `nativeMethods` 和 `propertyNames` 分项；强制分项计数是正整数、分项总和等于对应总计，三样本一致性也比较这两份分项。观察器继续保持实际方法参数/返回值与能力保护，不改生产代码。定向测试新增缺失/截断/非法bucket负例及实际Lua归因断言，共6项通过。

一次新观察器诊断中，300帧的3600次方法调用分为SetVisible 2100、SetAnchoredPosition 900、SetLocalScale 600。该数字只用于定位调用来源，尚未证明重复写入可安全省略，也不是正式三样本或优化收益；完整路径含主动待机动画。此前两份schema1报告保留原样，不能冒充schema2或#521新核心组合的测量。正式分项三样本、源摘要与独审将在#521最终合入组合上刷新，所有AC继续未勾。
