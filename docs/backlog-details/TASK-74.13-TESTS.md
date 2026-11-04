# 卡牌定义管线：独立差分与语义变异

完整旧源固定在 `tests/fixtures/card-definition-before.json`，基线 `b4ac63145689b9dd632db100eee49087f6182b39`，旧完整源码 SHA256 `2e6a406674d95f0037892120301b684857414dc75b9b225fec2052ff8ed6b55a`。测试绑定新完整源码 SHA256 `5501bec075d05706b39f349a075c33d830738f3f605e5e18e0d03ab33dd75bbb`；正常回归不依赖 Git，不冻结无关 prefix/suffix。

固定 Node24.18，四组独立旧/新 VM 共 24 次定义查询（含四种异常优先级），每组/VM 保留原 30 秒预算：

| 组 | 重点 | 完整 trace 字节 |
| --- | --- | ---: |
| native | Perfected Strike 包含自身的计数只做一次、Strength 不重复烘焙；后续适配器改变 target/experimental 后仍使用原 native 捕获；无 player 的 Searing/Burn | 135581 |
| adapters | 十二个真实 adapter 实际执行后各返回一个新对象，下一阶段必须接收前一阶段的 marker；Shiv 覆写后再追加实例伤害 | 138365 |
| costs | Blood 旧 reduction 与持久费用、0/nil/旧0与 source -1 X 哨兵、Corruption/turn/freeOnce、Necronomicon 快照/freeAttack、Medical Kit/Blue Candle | 141104 |
| copies-errors | 完整目录脱离、副本独立、值 alias/cycle、共享 copy 的 table-key 身份、显式 false、Searing/unknown/trigger flag/damage/cost 的异常先后 | 135241 |

每次单独查询都对完整 `state+instance` 图做前后相等断言，包含完整 catalog、rules、sourcePools、事件、所有实际独立 RNG（monsterHP、AI、shuffle、cardRandom、card、misc）和 legacy seed。没有禁用 RNG API。每组 trace 保留所有完整定义/异常，以及完整最终共享输入图和别名；部分测试在查询之间设置状态/遗物，因此不将最终共享输入 trace 冒称为每次查询分别冻结的输入快照。

函数以类型标记表示；适配器真实返回对象的承接、原目录不变、循环/别名、table-key ABI 和独立查询副本身份另有显式断言。string 异常只移除 Lua 文件/行号诊断前缀，原消息、先后及非 string 对象不改写。

十二个真实源码变异均由 `[DEFINITION_PIPELINE]` 行为断言拒绝：原生 Strike 重复计数、适配后重算 native、丢弃 adapter 新对象、漏显式零费用、Blood 二次减费、禁用 native Corruption、Necronomicon 在 freeAttack 后取值、X 被普通 freeAttack 改写、丢弃 Medical Kit 新对象、移除目录 copy、先查目录再验证 Searing、把 Shiv overwrite 移到实例 bonus 之后。解析或 runner 失败不能计为 kill。

新差分/变异 **5/5 通过、0 skip，46.55 秒**；增强无 player 既有 nil/nil retained-marker 行为断言后，对应两组再过，输出身份不变。原职责复杂度逐项超限/缺测合同 **14/14 通过**，所有新增函数和嵌套匿名函数都在同一 CC15 合同内。

独立负责的八份原回归均过：corruption_cost、corruption_cost_integration、warrior_strength_build、silent_shivs、molten_egg_searing_copy、defect_genetic_copies、free_attack_x、colorless_attack_display。另六份实际 preview/V4 回归由实现者独立执行，来源见主附件和源码证据；V4 预览在副本真实 play，未用禁止全部随机的方式伪造只读性。

保留两个既有细节：基础 Whirlwind 的 `cost=0,costMode=all_energy` 与职业 source 的 `cost=-1` 均不改；局外 `silentRetainTurn=nil` 与 `state.turn=nil` 相等时，原 SilentFinal 会生成 `selfRetain=true`，本次明确保留，不顺手修改旧语义。

机器来源、分组 SHA、八份回归耗时及限制见 [card-definition-tests-20261105.json](../evidence/card-definition-tests-20261105.json)。先 `npm run build:data`，再 `node --test --test-concurrency=1 tests/card-definition-pipeline.test.mjs`；普通 raw 仅打印四组摘要。独立最终组合复审、Full、合后提交验收另记，没有官方导入、ready 或设备/FPS 证据。
