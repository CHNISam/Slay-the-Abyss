# M9 / TASK-74：Actor普通伤害管线

基线为本轮fetch后的 `32c7096972212fea5a1e0607657103f77986d477`，提交标题为 `docs(roadmap): 梳理 M9/M7/M8 候选排期与活动核验 (#483)`。该基线Actor源码与此前aa4d56f5相同；不把它误记为在途PR486合入。本片仅改 `abyss_actor.lua`、专用测试/对照工具与本证据，不改Combat/CardActions、共享配置或冻结历史inverse。

## 职责与顺序

`M.damage` 保留活动源/目标拒绝、捕获原HP、共享area批次的onAttack引用，以及最后的死亡反应、事件帧和批次解析。中间分为六个同模块阶段：

1. `damageAmount`：保留normalAmount的有限整数/二进制64上限检查、fixed互斥、正常修饰及Spire Pair实际伤害。
2. `consumeAttackBlock`：按原顺序处理Intangible、格挡耗尽回调与非fixed的Boot最低伤害。
3. `modifyIncomingAttack`：Buffer、Heart上限、Act3及玩家attacked队列、Torii、最后Tungsten和计分，顺序不变。
4. `applyAttackHpLoss`：保留怪物wasHPLost与玩家onAttacked的相反Plated时序、Act2/Book、Writhing、扣HP、通知、伤害事件、Fairy/遗物及inflicted回调。
5. `queueHitPowers`：非致死NORMAL的Curl锁定及BOTTOM动作、Angry的TOP批次。
6. `queueAttackedPowers`：保持Thorns/Flame Barrier/Block Return的原power获取顺序和独立action引用，不把多次回调合并。

`directDamage` 是不同协议，未复制、合并或修改；原 `queuePlayerAttackedReactions` 也保持原样。不是规则重写或数值调整。

## 本轮完整指标

Luacheck1.2.0固定SHA工具、luaparse0.3.1及Node24.18.0，全部320模块测量5036/5036→5042/5042项，新增6函数均纳入。

| 函数 | 基线CC/跨度 | 最终CC/跨度 |
| --- | --- | --- |
| M.damage | 61/83 | 10/20 |
| damageAmount | — | 9/15 |
| consumeAttackBlock | — | 12/11 |
| modifyIncomingAttack | — | 5/10 |
| applyAttackHpLoss | — | 4/15 |
| queueHitPowers | — | 15/18 |
| queueAttackedPowers | — | 12/17 |

受影响7职责最高CC15，最长20行。决策点Σ(CC−1)仍60，含函数基数的CC合计61→67；没有宣称业务分支消失。Actor模块909→938行、62→68函数，模块最高CC61→60（原 `M.statusView` 残余）；其他Actor热点继续保持未治理。

本片独立基线下全库CC>15数量290→289、CC>30数量83→82；最高CC88、最长函数1004行、>1000行文件2个均未变。唯一依赖对1461、架构调用点1853、最大完整SCC103模块/789内部调用点不变。SCC成员、方向、调用重数及deferred分类相同；精确调用行位随代码移动而不同，机器证据保留 `cyclesIdentical=false`，不隐去坐标变化。静态15条告警逐项相同。

机器证据：[m9-actor-damage-20261103.json](../evidence/m9-actor-damage-20261103.json)。主控负责将上述7个准确 `function '<name>'` subjects 接入其独占静态责任门禁。本片新wrapper也检查全部7函数及区域内所有嵌套/新增函数完整测量与CC15。

## 行为证据

- 新夹具覆盖32组攻方fixed/普通伤害×基数×格挡×Intangible/Boot组合、16组防方Buffer/Torii/Tungsten组合，normalAmount负数/非整数/NaN/无穷/超2^53与合法上界、无效活动源/目标、共享area原reaction引用、逆TOP的双Thorns与Curl FIFO，以及公开C.play中后续效果抛错后的完整对象图回滚和原UID重试。
- 4个真实源码变异（fixed错误应用Boot、接受2^53超界快照、Tungsten移到Torii前、TOP反击反转）全部由 `[ACTOR_DAMAGE]` 行为断言拒绝。
- `tests/helpers/actor-damage-parity.mjs <精确基线SHA>` 读取完整旧Actor，在独立旧/新Fengari VM执行新夹具与原Plated/Fatal/Fairy/Ending/HP边界夹具，完整状态、事件、返回值、队列/RNG及对象图别名输出逐字相同：112+281+24+25+30=**472边界**，每边输出均完整写盘比较，不改原30秒VM时限。
- 轨迹序列化仅省略不可变catalog/rules/sourcePools/statusDefinitions；公开回滚夹具另逐表检查全部原始键值和引用，包含这些目录。各fixture独立，不复用旧日志；本轮旧/新源hash、轨迹hash及字节数见机器附件。
- 新夹具首次误把Thorns分类为普通damage事件，按生产真实 `status_damage` 分类修正后才得到正确顺序断言。变异源首次因Windows CRLF的多行锚点未匹配而失败，统一测试读入换行为LF后验证4个行为kill；未改任何产品条件或降低断言。

## 验证与剩余边界

通过的标准入口：`node --test tests/actor-damage-pipeline.test.mjs` 3/3；原plated/fatal-hp-loss/ending-damage/hp-loss-action-boundaries wrappers 4/4。另原 `hp_loss.lua` 27组、`block_damage.lua` 25组、`curl_up.lua` 28组、`tungsten_rod_card_hp_loss_edges.lua` 6组全过。

`check-engineering-quality`、`check-lua-static`（15条历史警告无新增）、`check:architecture`（320模块/1853调用点）、`git diff --check`通过。首轮检测到提取函数多余state参数，删去未用参数后重新通过，未豁免告警。

重放先按项目入口构建data/ui/theme和map布局，然后用固定Node24执行上述wrapper及 `node tests/helpers/actor-damage-parity.mjs 32c7096972212fea5a1e0607657103f77986d477`。完整本轮前后质量在独立树 `build/m9-actor-before.json` / `build/engineering-quality.json`；旧源、驱动及全轨迹在 `build/actor-damage-parity/`。

本片未跑重复整套CI；最终组合独立复审、精确HEAD必需CI与Backlog由主控执行。没有候选写入、官方导入、新ready、PC/手机证据，不声称设备提速或整个M9已完成。
