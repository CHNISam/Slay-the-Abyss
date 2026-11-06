# M7 最后有界核心切片

基线为已实际合入 #521 的 develop `c685409d7d34d91cae79e917090fe4299184ca8b`。完整333模块源码摘要、全图1920处require、两个SCC逐成员和每条内部边位置、全部237个CC>15测量及三个修改模块的每个函数见[机器证据](../evidence/m7-final-core-20261106.json)。采集时工作树尚未提交；实际候选SHA、独审和托管交付由PR收据绑定，不把本地报告写成主线成绩。

| 同算法完整口径 | 基线 | 本切片 |
| --- | ---: | ---: |
| 模块 | 333 | 333 |
| AST/Luacheck完整测量（含匿名、嵌套及初始化块） | 5370 | 5385 |
| Combat SCC成员 / 内部位置 / 唯一对 | 82 / 626 / 402 | 81 / 623 / 400 |
| Session SCC成员 / 内部位置 / 唯一对 | 15 / 62 / 41 | 15 / 62 / 41 |
| CC>30 | 61 | 58 |
| CC>15 | 240 | 237 |
| 最高CC | 75 | 75 |

Codex原先由同一个 `choose` 导入CardActions生成、升级和插牌，再提交选择完成。现在其 `selection` 只检查原已保存offer；实际生成、插牌、RNG和完成事件放回原有Combat选择快照事务。返回原offer引用，保留实现判定回调后使用同一offer的时机。Codex不再依赖执行器，唯一出边是Events，真正退出Combat SCC；没有传入执行器掩藏require、动态注册或增加模块。

V4只治理此前已明确建议的三个职责：效果schema验证、按闭合效果族执行、root阶段协调。保持聚合支付→唯一快照→逐效果→角色资源结算顺序；原 `execute` 的resolvingEffects恢复、原错误对象和EnemyAI flush不改。所有新增helper、三个入口及其嵌套函数受现有CC15硬门禁；Codex全模块及Combat新提交helper也受检。原V4 preview/snapshot/trigger等未治理热点保留，不把最高75或剩余58个高值称为完成。

本轮本地验证包括原1200冻结卡向量及原子性/生命周期23项、Act2遗物7项（其中Codex真实9场景）、独立旧新VM全状态图（含别名、函数/元表、事件、随机、返回及晚失败回滚）、支付与快照及Codex RNG三个可解析真实语义负控。额外比较直接execute支付后/伤害后的部分写入和原错误对象。新三owner完整旧源保留Git blob与SHA，当前三owner每次新鲜校验；原35-owner来源epoch及全部旧冻结hash/oracle不变。

静态14条旧告警、无新增豁免；1769项受治理测量通过；架构、指引、Backlog和diff检查通过。CI仅新增一个顶层JS测试 `tests/m7-core-final.test.mjs`，无新增raw Lua测试；库存与未测成本由唯一集成者登记。独立精确HEAD深审、PR Full、队列组合Full和合后develop Full未完成前均保持待验，不预勾TASK-74.19/.20交付AC。

剩余Combat81成员仍包含战斗规则、动作队列和角色状态协作；Session15成员仍有原Run事务的反向调用。完整残余风险继续由[原逐项材料](M7-CORE-REMAINING-RISK-20261106.md)约束，V4本次三项之外没有重新评级或自动接受。后续负责人Furinya，在相关玩法变更时按既有状态owner及回归维护；本轮结束后不主动启动下一M7架构切片。

本切片没有候选导入、真实ready、官方容量或设备实测，不能用离线等价代替这些证据。
