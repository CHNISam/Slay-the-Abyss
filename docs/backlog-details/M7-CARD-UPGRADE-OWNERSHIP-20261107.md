# M7 卡实例升级所有权

接续 Owner 的 TASK-74.19 架构优先指派；实际开发基线为 `d8a57cae2a867200ca8e588abc0d368e6cdb3799`。开始前 fetch develop、读取当前 Sprint/任务池并逐项核对开放 PR #541–549 与活动工作树；搜索列表未涵盖全部作者，另逐项补核。后出现的 Actor #551、Potion #550 也无生产重叠。task:pick 返回既有任务 HOLD，不重新认领或改变 Owner/AC。

## 实际职责

`abyss_card_upgrade` 持有卡实例升级资格、Searing Blow 构造副本校验、战斗基础费用及升级费用/次数的可执行规则，仅依赖 Copy。Blood for Blood 的完整定义复制、费用取值和升级钩子归同一 owner；不是空的能力注册表，也不通过回导 Combat 延迟初始化。

Combat 的四个公开槽 `combatBaseCost`、`validSearingBlowCopy`、`canUpgrade`、`upgrade` 和 WarriorStatus 的 `onUpgrade` 固定转发到该 owner。普通赋值、函数身份、nil/false 和调用中的后续动态读取保持；后加载门面不重新赋默认值。WarriorStatus 的私有 definition/cost helper 在加载时捕获原 owner 实现，其余 HP-loss、生成、执行和计划函数未改。

Stasis.death 仅将原 Master Reality 分支的 require 目标改为新 owner。原手牌数量严格相等判断、原卡身份、两次 canUpgrade 读取、忽略 upgrade 返回值及现有回滚事务保持。升级规则从主战斗编排中分离，不再为归还一张扣押牌初始化 Combat 执行链。

## 同口径测量

[机器证据](../evidence/m7-card-upgrade-ownership-20261107.json)保存全部源码摘要、require位置、SCC成员/内部边、静态测量及原始验证记录。

| 指标 | before | after |
| --- | ---: | ---: |
| 模块 / 全部测量 | 333 / 5386 | 334 / 5396 |
| 完整 require 位置 | 1920 | 1922 |
| Combat SCC：成员 / 内部位置 / 唯一对 | 81 / 623 / 400 | 80 / 619 / 397 |
| Session SCC：成员 / 内部位置 / 唯一对 | 15 / 62 / 41 | 15 / 62 / 41 |
| CC>15 / CC>30 / 最大 CC | 237 / 58 / 75 | 236 / 58 / 75 |
| 静态历史告警 | 14 | 14 |

只有 Stasis 退出 Combat 环。Act2Powers 仍经 PowerOrder/TurnPowers 等回环，不能把尚未合入的独立 Power 切片收益计入本片。所有即时与已审延迟边均进入同一 AST 图，未过滤计数。

原 upgrade CC16 按 Blood 费用与普通保留费用分支拆为两段 private helper，公开入口 CC10；新 owner 全部函数和初始化最高 CC13，完整纳入原 CC15/1000行门槛，四个固定门面桥及 Combat pairs 迭代器也受原 CC15。原 Stasis→Combat deferred 例外因对应边真实消失而删除，没有新增豁免。

## 验证与兼容范围

使用完整333源码不可变归档作旧侧，归档仍如实标为2ad；逐文件 Git blob 核对其与实际 d8 基线完全相同。五owner来源证明包含3旧Lua、新owner witness及完整architecture配置；每次投影鲜读真实owner，旧/未知/部分输入不授权读取。旧源码、guard、oracle、read counts 和历史归档不改。

独审已逐AST核对7个迁移函数与两个分支helper内联后的 upgrade；其余160个 Combat、18个 Warrior 顶层函数保持。小型独立旧新探针对费用、nil/false、动态替换、表异常和读写顺序一致，真实 owner/Stasis 禁止 Combat/Warrior/Actor/CardActions/Effects 加载仍可执行。

Combat 的 pairs 公开 API 复制是实际契约：逐项读取真实字段和四个动态槽，nil跳过、false保留，每个迭代器独立，无重复键或owner私有helper泄漏，不承诺 Lua 原生hash顺序。兼容声明仍不覆盖模块的 rawget/rawset/next/元表替换、WarriorStatus pairs形态，或清除两个门面 package.loaded 后的热重载。Copy.copy 的捕获提前，Stasis先加载后、旧 Warrior加载前故意重写 Copy.copy 的跨加载交错不作等价承诺；加载 Combat 前安装的既有 Copy 探针必须保持。

源码迁移会改变 Lua 原生错误位置。只允许实际观测、完整错误串及逐字核对的同一语句位置作精确对照；原始错误值和 table 身份保留，不通配剥离前缀或修改产品错误。

必要旧Drain回归曾真实失败：pairs(C)复制缺canUpgrade，CardActions:114在排队Armaments路径抛错。未改旧测试或将该消费排除；Combat新增窄pairs迭代器后原75组通过，另补真实复制API到选择/升级/弃牌的旧新差分。此前20/20不是最终修复通过证据，旧失败和修复前成功观测均保留。

最终新增JS21/21、raw Lua11组通过；两个独立VM的15个全字段检查点逐字相同，每侧885,975字节、5,245个完整对象定义。包含原Stasis晚失败完整回滚/重试与真实复制API的Armaments选择完成；8个真实可解析语义变异由具名断言检出，6个冷加载组合保持槽位身份。13条完整错误串映射均对应已核验原语句，原抛值和两个未改变的Stasis错误不改。

完整新文件成功wall28,383.441ms、Node28,317.243ms，28,384ms为本地planning候选；此前20/20成功wall26,404.203ms及所有失败观测均保留。原raw Lua成功最大848.269ms保留849ms候选，不因最后较快而降低。实际精确小数及环境以机器证据为准，未写入共享timings或放宽旧预算。

初期 /usr/bin/time 不存在，未执行Node；首次已执行新文件15/16的失败来自测试局部collector误计未提供文件的缺失报告，按真实policy目标文件修正，门禁未改。开发fixture曾把Searing count-only结果27误写28，两侧同败后仅修正期望；生产不为该测试改变。原工程未分类新模块/陈旧deferred例外的RED与所有后续成功日志均保留。

最终来源69项复验、CI库存8项、既有definition pipeline5项及6份原Lua另见机器证据；pairs修复后原drain与registry再次通过，其余原回归使用的规则函数在该修复中不变。独审在提交外绑定精确HEAD/BASE/tree。当前仅本地窄测，不将其声明为 Hosted、Full、官方导入、真实 ready、设备或M7完成验收。
