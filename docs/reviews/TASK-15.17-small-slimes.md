# 小软泥遭遇：一小一中与开战随机事务

2026-10-24，TASK-15.17 / PR174。本切片只修 small_slimes 的两个合法初始编组及其进入战斗事务。不改敌人生命、伤害、AI、卡组、地图选遭遇概率，也不关闭完整遭遇分布、原作随机流或千星实机关口。

## 固定来源

参照社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。它不是官方开源授权或正版二进制认证。本轮没有原作或千星实机观察，没有搬运第三方实现代码。

- [MonsterHelper 的 Small Slimes 分派](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java#L427-L428)调用 [spawnSmallSlimes 完整方法](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java#L688-L699)。只抽一次当前 miscRng Boolean。
- true：Java slot 0 刺 S、slot 1 酸 M；Lua 数组对应槽 1、2。
- false：Java slot 0 酸 S、slot 1 刺 M；Lua 数组对应槽 1、2。
- [MonsterGroup 构造器](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java#L26-L28)保留数组顺序。[MonsterRoom 进入](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/MonsterRoom.java#L49-L55)才建立/初始化组，[房间创建入口](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L1826-L1833)取得已选遭遇 key。

本轮独立重算 MonsterHelper 文件的 Git blob 为 `a81763abf681642be66cbd935cc99d2126e822f4`，SHA256 为 `e6a60cdfa7af881d5f128a9532664ea33f32e71239cda49f3983fceac95a10e1`，与只读来源清单一致。

## 最小改动

1. small_slimes.enemies 保存 false 的合法数组，新增 enemiesOnTrue 保存 true 数组。现有 18 个遭遇只有本项声明该可选字段；验证器对两数组同样检查非空、敌人引用、tier 和分裂后五槽容量。
2. Run.startCombat 在现有前置校验后克隆当前 run.miscRng，抽一次 Boolean 并按数组顺序构造真实 Combat。包含前/后抽牌遗物的全部开战步骤成功后，才提交战斗和新随机状态；没有该字段的其他遭遇不抽 misc。
3. Nodes.enter 将新楼层与 prepare 后的 misc 状态放入浅层临时 run，仍调用同一 Run.startCombat。成功后只提交开战已有字段和该次返回的 misc 状态，不再临时修改 live floor，也不会把旧 clone 覆盖回来。未知房的 eventRng、概率、事件池仍按原流程独立提交。
4. Combat.new 的显式 options.enemies 保持原意，不会对低层 AI/UI 夹具偷偷重抽。

没有通用事务框架，没有新增 Run 公共参数或模块。已有损坏地图（例如手改 map.path=nil）不是正常 Map.generate/restore 结果；其原有 Map.choose 异常边界不在本片修改范围。

## 红绿与真实入口

专项先在旧生产基线上运行：16组中13红，错误明确为两只 S、未消费 misc 或失败后重试仍未消费；另数据验证7项中6红。补充自然路径和合法入口拒绝后，最终专项共18组：

- true/false 两分支，构造槽序、当前已推进 misc 流、一次消费、成功提交及重复调用不再消费。
- 完全未改的 seed1：Run.new + Map.generate + Nodes.enter(f1_l2)，真实首层 small_slimes。
- 完全未改的 seed23：从 f1_l2 用原80生命/初始牌组与合法出牌打赢，跳过奖励并回图，进入自然问号 f2_l2；自然转为 small_slimes，开战时66生命、1胜场。没有改地图、事件概率、敌人值或强塞胜利。
- 两个受控 Boolean 的问号路由夹具另用 seed222，只有首层地图符号改成问号，用于隔离路由分支；不把它当自然路线证据。
- direct Run、普通 Nodes、未知转战：真实 Combat 构造完成后注入返回失败/异常，检查所有既存嵌套表的身份和每个字段原样，恢复后重试等于新鲜成功。
- 后抽牌遗物失败、非法遭遇/楼层/遗物、非法/不可达节点及地图归属拒绝不消费、不换引用。
- 其余17遭遇按独立字面量成员/槽序构造，整场初态与原显式 Combat 相同且不新增 misc 消费。

## 旧夹具分类

- acid_slime_s_ai.lua 的末组不是独立 AI 算法错误，而是误把两 S 当真实遭遇。保留 Run.startCombat/endTurn 集成入口，改成 seed222 的真实 false 分支：酸 S Tackle3 + 刺 M Flame Tackle8，总失血11；酸 S 后续交替和一次 misc 断言保留。
- spike_slime_s_ai.lua 的末组同理，保留 seed42 真实 true 分支：刺 S Tackle5 + 酸 M Spit7，总失血12；刺 S 后续动作和一次 misc 断言保留。
- encounter_coverage.lua 保留18遭遇、合法层端点、256种子地图、10回合和失败/奖励契约。仅 small_slimes 的 seed42 成员预期改为来源的 true 分支；其余17组完整原断言不变。
- 显式两 S 的独立 Combat 测试仍允许存在，代表底层演员组合测试，不再称其为原作普通遭遇。

## 验证与未完成边界

本轮使用既有系统 liblua5.4 helper，没有安装软件、npm依赖或Fengari，没有使用用户电脑/Codex。battle_ui 使用真实 battleLayout 生成 ABYSS_TEST_LAYOUT，而不是宽松替身。原生 Lua结果不等于Fengari、Windows或千星结果；当前PR提交CI由集成方另验。

最终原生Lua全158文件通过（含18组新增专项、真实布局battle UI）；Python17项通过，数据验证和JavaScript语法检查通过。首次Node选择1009项中1007过、2失败：叙事原包检查因精简快照缺输入失败，随后从实际develop读取两份原包、独立核对Git blob并重跑通过；地图导出桥仍因未安装Fengari失败，不伪称通过。原生首轮15文件缺LUA_PATH的宿主加载失败记录已保留，修正宿主环境后全套重跑，无生产补丁。完整独立文件manifest、旧基线/最终候选diff及红绿/回归日志随交付封存。未执行完整 npm check、平台编译、官方导入、原神实机。

本片保留 medium_slimes、gremlin_gang 的已知来源缺口，不改 TASK-47 冻结内容。地图仍不是原作弱三/强池队列，HP/AI/洗牌仍有共享LCG历史，misc完整消费者顺序也未认证；一次局部Boolean接对不代表全原作RNG一致。

## 修复后正常路线补证：旧胜利不能沿用

在本片冻结生产上，原样运行已有 m2-resource-audit 与默认 m2-autoplay-policy，固定既有种子1、2、3、36、42。没有改生命、卡组、敌人数值、地图、路线/出牌策略或种子来补通关；这些是正常游戏结果，不是事务断言失败。

- seed1：16层守护者战败，5胜、17牌、24金币。
- seed2：16层守护者战败，5胜、15牌、103金币；首层刺 S + 酸 M。
- seed3：16层守护者战败，5胜、17牌、19金币；第2层酸 S + 刺 M。
- seed36：16层守护者战败，7胜、18牌、135金币。
- seed42：6层暴怒角兽战败，3胜、12牌、144金币；首层刺 S + 酸 M。

5局全部以0生命正常进入失败终态，资源/重复命令拒绝账本及新局清洁断言通过。脚本exit0只代表审计正常完成，绝不代表5局获胜。用同一原脚本回跑未修复生产基线：seed3原17层胜利（25生命/105金币）、seed42原17层胜利（34生命/131金币），如今已变为上述正常败局；seed2原5层败，本片推进至16层败。seed1、36仍在16层败。

小软泥组变成原作合法的一小一中，同时正确消费misc，足以改变实际战斗与后续随机状态。不能为了维持旧策略通关而恢复错误两S、调低数值或改策略造绿。也不能由这5个固定诊断样本估算胜率或断言游戏不可通关。旧522e547千星实机和PR168旧seed通关结果不认证本片；本片17层胜利仍须独立复核，平台实机仍须新取证。完整逐步账本和原始/摘要文件由集成证据包保留。

补充只读正控：预先限定沿用同一未改策略、按seed4至32升序尝试，首个正常胜利即停止；实际只跑4、5、6、7。seed4/5在16层败，seed6在5层败，seed7正常完成17层Boss宝箱，最终15生命、150金币、19牌、8胜，遗物为burning_blood、bronze_scales、sozu；失败后/胜利后新局清洁断言均通过。seed7仅证明该固定策略下存在正常数值的离线完整路线，不替代前述5个失败样本，不是胜率估计、原作分布认证或平台实测。逐步动作与资源正控账本随证据包保留，尚待独立复核。
