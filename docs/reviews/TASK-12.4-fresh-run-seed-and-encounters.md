# 正常新局种子修复与第一幕遭遇审计（2026-10-24）

## 已修复的入口

`abyss_game_ui.new` 原来每次都建立 `seed=1`，`start` 只在当前 Host 内加一。官方重新挑战、重新进入或客户端脚本重建后都会回到 1；这是固定地图与固定遭遇重播的源码根因。具体遇到哪组还取决于所点地图节点，不能仅凭两组敌人名称认定原版池已经错了。

正常 Host 现在只在接受一次 Start 时读取 `abyss_new_run_seed.next()`，用允许的 `os.time()`、`os.clock()` 微秒精度格式和本模块已接受开局序号混合为 0..65535。菜单预览固定使用 1，但不会当成实际 Run；refresh、update、非法重复 Start 不消费新种子。Run 与 Map 使用同一次样本，日志输出 `ABYSS_RUN seed=… source=clock|explicit`，便于下次实机核对本轮轨迹。没有调用 `math.randomseed`、更改规则随机状态或强制相邻局不同。

`platform.seed` 与现有 `ui.seed=42` 是显式复现入口，绕过时间采样，保留同 Host 重开加一及65535→0行为。现有共享测试夹具显式给1，避免正常新局随机化让旧规则测试随运行时钟变化。还允许注入 `platform.newSeed` 测试真正 Host 路径。

平台依据：工具知识页 `D:/MiliastraTools/genshin-miliastra-mcp/knowledge/notes/client-lua.zh-CN.md` 第294行明确记录该客户端实机可用 `os.time/date/clock/difftime`；`src/scene/client-api.json` 的 game 接口没有时间戳或随机方法，本次未编造 game API。`os.clock` 采样来自启动按键时的进程CPU时间，跨脚本重建不依赖本模块序号；序号仅辅助同一模块内样本。测试模拟同秒、不同CPU时间、模块重建；真实客户端的CPU时钟分辨率和重新挑战轨迹尚未本轮实机取证。

**边界**：这是正常入口熵修复，生产仍是16位种子域，允许自然碰撞；若模块重建且两种时钟返回完全相同值，仍可重放。同秒并非必然不同，不能承诺每两局都不重复。没有加入64位原版局种子、没有将TASK-12.4的完整地图隔离候选接入生产。

## 固定原始实现与证据等级

本轮实际读取以下固定提交的方法体，完整下载与OpenCode调用证据留在此工作树 `.artifacts/fresh-run-rng/`；来源清单与hash另存 `docs/rules/evidence/fresh-run-seed-20261024.json`。

- [aeubanks/sts Exordium](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/Exordium.java)：108..183，第一幕列表、权重和强敌起点排除；53行 mapRng 初始化。
- [aeubanks/sts AbstractDungeon](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java)：378..391 初始化分类随机流；1037..1075 抽取与重复限制；1674..1687 消费队列；1727..1731 按局seed+层重建战斗相关流；1826..1841 从队首创建遭遇。
- [aeubanks/sts MonsterInfo](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterInfo.java)：23..50，稳定按权重排序、归一化、binary32累加和严格小于阈值。
- [ButterflyGame Exordium](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/dungeons/Exordium.java)：136..237，独立固定镜像交叉核对同一池、权重和排除规则。

这些是社区反编译镜像，不是官方开源。本轮未核验正版PC二进制hash或实跑PC版本，不能将两镜像一致称为官方版本认证。来源账本既有声明保持有效。

## 原版队列与生产差异

| 项目 | 固定方法体证据 | 当前生产与剩余工作 |
| --- | --- | --- |
| 前三场普通遭遇 | Exordium先生成3个弱敌队列项。Cultist、Jaw Worm、2 Louse、Small Slimes各权重2，初次各25%；拒绝已抽的最近两种，因此首三项互不相同。 | Map按地图层数过滤 min/maxFloor，并给每个战斗节点预抽。不是按实际普通战次数；四种弱敌仍允许到14层。跨非战斗楼层后第三场可能进入强池。 |
| 强敌池 | Blue Slaver2、Gremlin Gang1、Looter2、Large Slime2、Lots of Slimes1、Exordium Thugs1.5、Exordium Wildlife1.5、Red Slaver1、3 Louse2、2 Fungi Beasts2，总权重16。 | 生产以可进入的内容条目等概率抽取，没有组级权重。不得把未实现内容静默移除后声称概率对齐。 |
| 弱→强边界 | 先额外生成首个强敌，再生成12个；末弱敌为2 Louse时排除3 Louse，为Small Slimes时排除Large Slime/Lots of Slimes。通用排除还列Looter→Thugs、Blue Slaver→Red Slaver/Thugs。 | 没有实际弱敌队尾记录、首强敌排除或完整遭遇队列。 |
| 连续重复 | 普通队列拒绝与前1或前2项同名，每次拒绝继续消耗 monsterRng；精英队列拒绝前1项同名。 | Map每节点独立抽一次，无此拒重；不能用“相邻新局首战不重复”替代同局队列规则。 |
| 随机流 | monsterRng独立于event/merchant/card/treasure/relic/potion等对象；普通与精英列表都消费同一个monsterRng。mapRng来自局seed+actNum。HP、AI、shuffle、cardRandom、misc在层转换时由局seed+floor重建。 | 地图房型与遭遇已有独立LCG对象，但都是16位；不是原版monsterRng。Run仍共享战斗/奖励等可变seed；问号转战斗从当前run.seed另建临时抽样，没有消费统一普通遭遇队列。miscRng在当前Run中不按层重建。 |
| 编组与内容 | 沿用已有 `TASK-15-encounter-composition-audit-20261024.md` 的MonsterHelper审计，并同步检查最新dc487e6。 | TASK-15.18现已修复四小魔池，不再列固定五敌为当前缺口；其misc/HP/AI完整原版流和medium_slimes缺口仍按既有任务保留，本次不重复其实现。 |

因此“每次重进都是同样序列”由Host入口修复；“一局内是否是原版前三弱敌/权重/重复规则”仍是TASK-12.4必要工作。实现队列时须由Run拥有怪物流、队列和游标；Nodes在实际成功进入普通/精英房时事务消费，问号转战斗复用相同普通队列；Map显示与快照恢复不得另抽一组。先固定同来源的独立向量，再接流和完整编组，不能用当前均匀地图样本自重放冒充原版oracle。

## 验证与平台边界

真实Host测试 `tests/lua/game_ui_seed.lua` 首次在生产旧入口失败，断言是“正常Host忽略newSeed仍用1”，修复后6组通过：采样时机/拒绝Start、重建Host、显式复现真实遭遇和HP、0/65535重开、非法样本原子性、原生OnStart同秒模块重建、源范围与私有流不变。部署清单回归确认新模块进入正常候选。

已有Host/序章/节点卡牌归属/BGM专项通过；初次全check在JS872时中断，因为同步dc487e6四小魔实现后需按冻结新源重跑，不计该跨源运行通过。最终全量check结果在本轮Backlog备注。没有创建新副本、写入存档、导入或游戏实测；TASK-12.4广义AC保持未勾。

免费委派：OpenCode1.18.24 / `opencode/deepseek-v4.1-flash-free` / Max，目录输入输出缓存价格均0；有效配置锁住主/辅助模型、Provider与白名单，仅读指定五文件和Backlog overview。超过90秒无任何JSON事件或文件产出，停止并由Codex接管；无可验收模型产物，无法从空事件核实实际费用或节省额度，未回退付费模型。
