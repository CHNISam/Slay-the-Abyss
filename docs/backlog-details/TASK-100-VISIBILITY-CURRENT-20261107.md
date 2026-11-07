# TASK100：当前核心组合的可见性验证

以 develop `de218e5c4d8a8f71c9641e3499c8d6943c0b82ea` 接续 #532 `6bb9c21ee174b9625a33e856b059b89a68faa50e` 的六个意图控件优化。生产仅修改 `abyss_battle_render_actors.lua`；不改 RNG、动画和其他运行时。原有17份生产、测试、基准和历史说明/证据按 Git blob 保留，旧不利三组、诊断和旧48样本不覆盖。

#538 `c816de48ee278f7f8a24246612e9637aeb2bd471` 的四个测试修复文件只作为当前工作树的待落地依赖，未记作已合。本切片不带回旧 Backlog 状态或共享 CI 库存清单；实际合并、独审和 CI 由当前集成批次继续。

## 来源与行为

固定 before 模块与当前 develop 生产文件经 LF 标准化后逐字相同，SHA256 `f535f2d14b15e8af3fe49bf3e3af45900b4cae4fcc8f8ccb29a407cf6fdcc6d9`。原协议493项路径库存与当前实际输入相同，加上受控协议脚本共494项。历史组合之后的实际生产源码变化是 Combat、OriginalV4、Codex 三模块；Windows CRLF 与历史 Linux LF 的字节差异也单独记录，旧48样本已不具备当前组合资格。

固定 Node24.18.0 执行可见性和几何26项定向合同全部通过，39.740秒，含 LF/CRLF 负控、原生 owner/lifetime/false/throw/重入/escape 与完整 Host 图。两独立 VM 的最终 Host/run/native 可达字段、别名、元表共20,329,626字节完全一致。静止300帧方法调用3600→1800、属性写入7200→5400，逐阶段 require/load/snapshot 计数保持。详见[本轮图与计数](../evidence/intent-visibility-equivalence-de218-20261107.json)。

## 唯一一次固定协议实验

原程序与协议不改：4组预热、20组主配对，奇数AB/偶数BA，48个 fresh VM，原30秒预算，保留所有样本且不重试。判据仍为50,000次固定seed bootstrap的配对log墙钟比单侧95%上界≤1.00，且 after P50/P95 均不高于 before，全部来源与工作量合同通过。

[本轮全部494来源与48原始样本](../evidence/intent-visibility-controlled-de218-20261107.json)已完成，所有样本退出0。before/after 墙钟 P50 为4910.378/4695.674ms，P95 为6858.818/5887.821ms；配对几何比0.946670604，单侧95%上界0.990271897，满足原判据。进程CPU P50为7640/7359ms，仅描述本轮。独立 Python 按同一预先固定随机序列重算结果一致，[重算结果及程序](../evidence/intent-visibility-statistics-de218-20261107.json)另存。

这是当前同源有限离线路径的证据。共享主机负载记录不等于完全受控，Windows loadavg 也不是有效的系统负载测量；fresh进程仍有JIT与观察器成本，20配对 nearest-rank P95不是稳定尾延迟。不能推算手机、原生Lua、FPS或所有战斗收益。未运行 Full、队列或合后验证，官方候选与设备仍 UNVERIFIED，TASK100 AC 保持未勾并交接 TASK-4.21。

完整提取范围、精确依赖、源码身份和报告摘要见[本轮收据](../evidence/intent-visibility-current-receipt-20261107.json)。上述测量工作树当时未提交或推送，后续由当前集成批次完成精确独审和正常准入。

## 集成读回

2026-11-07 02:03:07 UTC，#538 经原生队列正常 squash 为 `2c85bc618f39a4706dbc108eca0ebe5797630081`；实际提交即组合 Full `42323846768` 的受测 SHA，35 项作业及不可变 checkout 收据、三项 Actions 准入状态均已核验。早先收据的 `landed: false` 保留为测量当时事实，不改写历史。

集成树仅快进到该实际 develop，再独立执行现有 data/UI/theme 构建；上述 494 份实际输入逐项重新计算 SHA256，全部一致、缺失及漂移均为零。因此成本工具、Bonfire 回归与未执行协议的组合没有改变这条受测运行时路径。当前批次库存 746 JS / 1402 Lua 检查 8/8 通过；共享工程采集与静态/架构门禁通过，333 模块、5386 处完整测量，原 CC>15 237 / >30 58 / max75 及两个 SCC 81+15 均未改变。此来源核对和定向结果不替代本批最终 HEAD/BASE 的独审、Full、队列及合后验收。
