# TASK-15 潜行与迟缓小魔：固定动作的不同roll消费

2026-10-23，`feat/continue-blue-slaver`增量，基线`8a70065`。仅补AI抽样请求，保留PR86已核对的HP范围、伤害、Weak、动作顺序与名称；不改Combat/Actor/Inventory，不开游戏/MCP或平台构建/副本写入/官方导入。全池与平台AC仍未完成。

## 固定源码证据

本轮完整只读核查固定社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)：

| 文件 | 实际取得UTF-8内容SHA256 |
|---|---|
| [GremlinFat.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinFat.java) | `6183151F7C05A3836BB679218BC2F27DCE110E94DDCE6C04A8947C1F3A07F051` |
| [GremlinThief.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinThief.java) | `6F6E3EB24A8DCB6D8502336F34F4B79A9EFCCA708C1EF5D8CF99C0763AFF8DE6` |
| [SetMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/SetMoveAction.java) | `2B6C9200A4574D514674214D342A24993D6BD7F9CE1AC81306FD308ADB443666` |

首动`AbstractMonster.rollMove`与动作末`RollMoveAction`调用链、文件hash延续已实际读取的[Spike S账本](TASK-15-spike-slime-s-ai.md)。旧动作/HP证据见[FAT_GREMLIN_ATTACK](../rules/FAT_GREMLIN_ATTACK.md)及[SNEAKY_GREMLIN_HP](../rules/SNEAKY_GREMLIN_HP.md)。

这些是未经目标正版PC构建号/二进制hash认证的社区镜像，不是官方开源、原作PC观察或平台实测。未执行或提交上游程序，只读后独立归纳机制。

## 不能把两只小魔配成同一种策略

| 项目 | 迟缓小魔/Fat | 潜行小魔/Sneaky（GremlinThief） |
|---|---|---|
| 保留A0数值 | HP13–17，基础4后Weak1，无A17 Frail | HP10–14，基础9，无减益 |
| 首动getMove | 固定攻击减益，但rollMove先消耗主整数 | 固定攻击，但rollMove先消耗主整数 |
| 正常takeTurn动作末 | 排RollMoveAction | 排SetMoveAction，直接固定ATTACK |
| 每次正常行动后的AI抽样 | 一次0–99主整数，值不影响固定动作 | 零；SetMoveAction.update只调用setMove，没有random |
| 本项目policy | 复用`rolled_attack` | 新`opening_roll_attack` |

两种policy共享既有初始化rollAttack函数；`rolled_attack`正常推进时再调用它，`opening_roll_attack`推进仅选择配置的攻击意图，不抽样。schema共用attackIntent/rollRange验证，不复制战斗或状态规则。仅数据增加policy，不修改伤害/HP/效果；没有新增Lua依赖或平台控件。

双方源码还含escapeNext/deathReact触发的逃跑、通知和不同动作分支，本片不实现或认证这些情境；不因当前首幕入口使用固定攻击就宣称完整GremlinLeader队列通过，也不修改尚未核实的五小魔编组。

## 共享死亡队列与随机流边界

Fat的正常源码队列是Damage→ApplyPower(Weak)→RollMove，因此在有同伴时Thorns反伤杀死攻击者，已排队roll属于另行共享修复范围；Sneaky末尾仅SetMove，无论其payload是否仍执行，都不会因此产生额外AI抽样。`opening_roll_attack`应排除在“死后仍执行queued roll”的kind名单外；已与战斗时序agent确认，名单仅包括有来源证据的相关策略。

此基线尚未整合共享修复提交`26ff410`，该修复与主线程新Weak轮末调度应由主线程保留，不能用本分支旧状态覆盖。本增量不改afterAction或共享文件。Fat反伤后尚未执行的Weak等完整动作队列也不因roll消费修复自动得到认证；旧Fat账本已将反伤/共享队列列为保留项。

生产仍为共享16位LCG，HP/AI/洗牌相关、模100偏差、原作独立流与种子映射未对齐。活体请求次数通过不等于原作随机流或同种子轨迹一致。首动声音/动画等MathUtils随机亦不计入本片AI流认证。

## 实际验证

- 新`fixed_gremlin_rolls.lua`8组，先5失败/3通过，首个错误为初始化仅HP1次请求、应有HP+AI共2次；实现后8组全通过。
- 覆盖两只各自主roll0/99固定首动、Fat连续6动每次一次roll、Sneaky连续6动零后续roll、混合实例仅Fat抽样、满格挡/零伤保留各自消费、行动前毒死无排队动作、Sneaky Thorns致死仍无后续roll、失败出牌原地回滚。
- 旧Sneaky8组与Fat11组原样通过：包括原HP全端点/Run入口、伤害、Weak、预览、实例与状态修正，未删除断言或替换数值。
- 新8项schema与相关敌人/原生打包校验共76项JavaScript通过，0失败/0跳过。
- 原18遭遇在256种子样本全部可达；23敌人/53意图/18遭遇、115组覆盖通过。专属policy按已有枚举规则转交独立动作测试，可达及合法层边界断言未改。
- `build:data`、`validate:data`、受影响JS语法与`git diff --check`通过；未运行本片完整npm check。`build/fixed-gremlin-schema.log`、`build/fixed-gremlin-encounters.log`为本地定向记录，不是PC或平台证据。
