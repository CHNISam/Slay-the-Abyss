# TASK-100：稳定意图可见性提交去重

这是已领取TASK-100的后续窄切片，依赖#523基线，不另领他人In Progress工作。最新#521的41文件清单不含本次生产文件`abyss_battle_render_actors.lua`；未修改Actor/Combat/Power或其他分支。#521最终核心组合仍须集成后重验。

## 实测与改动

完整Host的300帧诊断定位7个控件各300次SetVisible，其中每个299次连续参数相同。`name`另受UnitView控制，故保留其300次写入。本次仅缓存intentIcon、intent、intentHit、intentBadge、intentExtra、intentLabel六控件，按弱原生handle键及view binding token保存最后成功值，不比较父容器的可见性。

首次、值变更、新binding、新handle或dead handle仍调用原生setter。调用前撤销旧承诺，setter false/throw不缓存；重入导致写入所有权变化时不缓存。escape HUD是另一路writer，调用前后均撤销缓存，包括失败；保留原异常对象，不引入跨模块缓存owner。角色portrait位置/缩放及name位置每帧均真实变化，本切片完全不动动画。

## 验证

- 新隔离fixture覆盖首次/300帧、显隐/意图类型、A/B/A owner、fresh/dead、partial false/throw、重入前/后及真实escape writer的30种组合。6类语义负控针对owner/alive/rejected/overlap/escape-post-clear/no-cache。
- 现有意图几何合同12项继续通过，不修改原断言。新增可见性正例及负控7项通过，另完整Host A/B图比较通过。
- A/B均为全新VM，走完整基线路径；最终所有可达Host/run/native字段、别名与元表图约20MB逐字相同。保存完整旧模块并验证固定SHA256；不是每帧画面/事件顺序的完整证明，变化边界另由定向回归约束。[实际图摘要与逐阶段计数](../evidence/intent-visibility-equivalence-20261106.json)。
- idle300方法调用3600→1800，属性写入7200→5400；require/moduleLoad/snapshot计数逐阶段不变。不把调用次数下降换算成FPS、墙钟收益或设备性能。
- 固定Luacheck1.2.0：无新增诊断，现有渲染/职责复杂度硬门禁通过。完整架构检查通过，328模块/1902引用位置。

独审最初复现escape setter重入后留下缓存，已按上述协议修复并增加真实writer回归及删除post-clear负控。最终精确HEAD独审、原CI、#521/#523依赖及实际合后Full尚待，未重复本地Full。新增JS/Lua须在最终组合更新实际CI库存与未测成本清单；共享CI文件同时由#521/#525维护，暂不抢写。TASK-100所有AC仍未勾。

## 三组交错离线墙钟观察

`node scripts/benchmark-intent-visibility.mjs` 在同源下交错执行 before→after、after→before、before→after。每次全新VM、30秒原预算；保留同观察器和完整路径，仅关闭昂贵最终图序列化，图等价由前述独立验证承担。源集合前后相等，全部业务stdout摘要相同，同侧逐阶段计数一致，跨侧require/load/snapshot计数一致。[三组原始样本、来源与环境](../evidence/intent-visibility-timing-20261106.json)。

本次 before/after 墙钟分别为6002.97/5975.11、6209.17/5781.42、6077.48/5759.42毫秒。nearest-rank P50为6077.48→5781.42毫秒，P95为6209.17→5975.11毫秒；每侧仅3样本，P95就是最大值，不是稳定尾延迟或统计保证。计时包含VM启动与观察器；不能推广到官方Lua、手机或其他敌人数量，也不替代#521合入后的组合验证。
