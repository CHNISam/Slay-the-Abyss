# TASK-15.13 · 大型棘刺团分裂与身份安全

## 范围和状态

初始基线 `b2ed2789bf553801dfa25d39dec7dbcd74c42919`，最终集成基线为已合并 PR143 的 `2925f688f9b1b5751a17009b54e939c03eda837b`。本片接续 TASK-15.12，仅为已有 `large_spike` 普通遭遇的 Large Spike Slime 接通分裂，复用已完成的 Medium Spike Slime。没有新增遭遇、卡池、Boss、Ascension 等级或原创平衡。此前“半血分裂未实现”的记录是历史切片边界；本片的离线机制与真实生成控件已接通，但不等于完整敌人、原作随机流、千星实机或父任务验收。

独立源码审阅与本地回归为分开的证据；最终远端提交、当前 SHA Quality 和合并由 PR 记录。没有运行用户 Codex、安装依赖、执行完整 npm check、启动原神或沙箱、使用平台 MCP、编译/写入存档、官方导入或投稿。

## 固定规则与独立实现

1. 非致命 damage 边界在当前生命不高于 maxHp/2 时立即改为分裂意图，奇数生命上限不提前取整。只锁定一次，打断不立即生成子体。被完全格挡或零伤害仍是 damage 调用；单纯轮开始、死亡来源导致未执行的攻击不是。中毒、固定药水伤害、单体/范围伤害和荆棘按已有入口到达该规则。
2. 玩家仍可继续伤害父体。两只子体各自的当前/最大生命取分裂行动开始时的剩余生命，不取最初触发值，也不重新抽中型普通 HP28–32。行动前中毒可在本轮触发分裂；致死中毒或后续致死攻击取消分裂。
3. 来源是 `SuicideAction(false)`，不是逃跑，也不是一次普通伤害。本实现直接将父体 HP 置零，不触发死亡能力、荆棘、独立奖励或金币事件；在两只子体插入完成前不检查胜利，等价覆盖这里的 CannotLose/CanLose 保护。没有实现完整通用动作管理器。
4. 保留父体对象、ID、原有状态表及死亡位置。组内顺序为左子体、死亡父体、右子体；其他现有演员仍为原对象。新子体使用新 ID，新的状态表、0 格挡及独立 AI 历史，不继承父体中毒、力量、虚弱或其他能力。当前可玩遗物没有 onSpawnMonster 类效果，未假造未支持的遗物回调。
5. 源码显式 HP 子构造不调用普通 setHp 范围抽样。两只子体依次初始化并各消费一次主 AI roll，最后仍消费父体此前已排的 RollMove。敌方行动列表以对象引用在本轮动作开始前快照，因此插入不让新子体本轮行动，也不跳过或重复原队友。
6. 父体攻击中的荆棘触发分裂时，已排攻击后的 Slimed2 和主 roll 仍完成；活父体的分裂意图再恢复，留到下轮执行。源码 setMove 会立即追加历史，本地 `spikeLast/spikePrevious` 是实现表示，不宣称完整 moveHistory 数组逐项相同。分裂后的已死父体 roll 不影响存活子体历史。
7. 卡牌事务的既有原地回滚覆盖新增标记、意图和事件，不破坏原 actor/状态/事件引用。药水仍走既有副本提交路径，测试读取提交后的 combat，不把旧副本对象当成当前状态。

## UI 和容量

内部 `kind=split` 是专用调度标记，展示映射到既有 unknown 图标，不伪称攻击。可见“分裂”与自写的“当前生命”说明；复用批准主题、原有死亡淡出和五个敌人控件，不搬运原作代码、图像、音频、动画或长文案。没有新增原作 SplitPower 专属图标，也不声称逐帧动画和等待时间一致。

旧反馈逻辑把前后快照同一数组下标当作同一演员，1→3 插入会访问不存在的旧槽，混合队伍还会误判死亡。现改为 ID 对照：新演员无旧帧，不得冒认死亡；只让真正由活转死的原父体淡出。帧中的状态表仍是分离快照。

敌人按钮原来只有数值目标下标。现为触摸记录 actor 对象、combat、回合与 touch，Click 只消费同一身份的一次性凭据。既有 Down→Click 无 Up 的宿主和纯 Click 宿主保持可用；Down→Up→Click 也支持。旧父体按下后分裂，再收到延迟释放/Click，不能误击占据旧槽的子体。拖牌、菜单取消和药水/牌的既有边界由全套回归保护。

数据校验计算包含保留父体的最大槽位：每只 Large Spike 最多占三槽，合法遭遇不得超过五槽。现有 `large_spike` 只有一只，分裂后占三槽；实际五槽控件用一只 Large 和两只现有队友验证。没有用静默裁剪、删除父体或改变原版数量绕过容量。

## PR143 合成与输入边界回归

在初始分裂切片完成后，PR143 将动态卡牌数值与状态详情合入 develop。最终合成使用其18个改动文件的准确 base64 字节并核对 Git blob；只在共同的 Combat/UI 文件整合分裂改动，其他16个 PR143 文件逐字节保留，未回退其卡牌预览、详情控件、生成布局、呈现脚本或测试。最终分裂差异仍限定为13个文件；不接管其他开发分支。

真实生成控件验证了新插入子体的目标预览（易伤后的打击9）与状态详情中的 actor ID。还保留并验证 PR143 的 `card_preview.lua` 和更新后的布局/中文呈现测试。

独立审阅在准确的 2925 基线上复现旧的多指详情关闭问题：选择打击，触点11按敌人关闭详情，触点12按英雄重置旧吞点击标记，延迟的触点11 Click 不应出牌。分裂切片的 actor 所有权令牌已阻断该序列。合成后又找到新的真实反例：敌人指针先持有令牌、另一触点打开详情，关闭详情的 Click 提前返回却保留令牌，重复 Click 可错误出牌；held 与 released 两种宿主序列均复现。另一反例为详情被别的触点打开又关闭后，旧敌人令牌仍有效。

修改前，持久化的四项合成回归为1过/3失败。修复只限敌人令牌：详情打开时通过既有 render 校验失效旧令牌；被吞掉的 Click 消费同触点的 held/released，不抢占另一个新触点。修复后四项全过，各自再用原数字 touch ID 的全新 Down/Up/Click 确认真正点击仍可出牌且只能一次。没有把共享详情系统改写为新框架，也不声称已完成所有平台多点触摸验收。

## 来源、版本及字节身份

2026-10-24 UTC只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。沿用 TASK-15.12 的11份准确源文件，新增 SpawnMonsterAction、SuicideAction、MonsterGroup、CannotLoseAction、CanLoseAction；所有文件的 base64 解码字节均重算 Git blob 和 SHA256。以下是本片关键方法链，其他共同文件见 [TASK-15.12 来源表](TASK-15.12-large-spike-slime.md)。仅提取规则事实独立实现，第三方源码不进入仓库。

| 固定文件 | Git blob | SHA256 |
| --- | --- | --- |
| [SpikeSlime_L](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SpikeSlime_L.java) | `a013282e75bde7d4a0088182558a016992a10650` | `a6a6976050a4f16507e0bbda75d4946f5eee3bbfc3d9787bc4e7a99f1d22269c` |
| [SpikeSlime_M](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SpikeSlime_M.java) | `d9ec26a2fa740ee4f1ccecb800b3a7f0b8e7984d` | `6eb1991db8ac36b1037871537c8669b135a58705ab2b33ca74550dcf84cad707` |
| [AbstractMonster](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [GameActionManager](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `1662da8de2aeb42044b385f03d0c801750904b13` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [SpawnMonsterAction](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/SpawnMonsterAction.java) | `fe2929d4752e0afc396fad7cffb1c866a564d5c1` | `731309c39e9d0143f187cc4c2b391cca1983d915aa53e84b95e4ec6907fedb4a` |
| [SuicideAction](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/SuicideAction.java) | `2d97ded6ee65a90e883197bd47927728069a5cae` | `66dbf76651c6499205c340d7f9304b031b19fd69cfd596475af209b21aeabd04` |
| [MonsterGroup](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java) | `7096970a151840489a3fba89806e6391e0d82d76` | `535770201b8aa8de01b52b185979af537f11ad0862e7d3e71ebb20cc64234221` |
| [CannotLoseAction](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/CannotLoseAction.java) | `737eac1b33accedc6428aac5ab5c1d7d981d3d85` | `65fc4b39c8ec5b8b33c97ff770fe0d1409caf2e1cfc56c54191f852db2d624dd` |
| [CanLoseAction](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/CanLoseAction.java) | `8990f85c6cb54a5007ed3297359a30ae23ab32ec` | `21ac8e1233dfe1f1eacc9213c4758f2bfc3295d737a66d335eefa12771b6a53a` |

镜像未与正版PC发行二进制 hash 认证，不是官方开源或原作客户端实测。生产仍共享16位LCG，不是独立 monsterHpRng/aiRng/shuffleRng、RandomXS128 或原版种子映射。构造/行动阶段消费已按受控输入验证，不等于完整随机分布或整局一致。源码 MathUtils 的视觉随机位置/动画不是本项目战斗 RNG 的消费，未把它混入规则随机流。

## 红绿与验证结果

- 生产前真实 Combat/Run 分裂 suite：0/14，14失败；生成控件失败于缺少可见分裂意图。初始 schema 12项为6过/6失败，其中已过拒绝例不冒称新的红例。
- 独立审阅新增了“半血、未标记、格挡挡住正常荆棘”真实反例：14过/1失败。修正仅在实际正常反伤发生时补充 damage 调用标志；死源攻击早退与合法死源已排反伤分开验证。
- 最终自带分裂核心18/18，通过奇偶阈值、当前HP捕获、两次子体/一次父体roll次序、固定药水、普通/毒/荆棘入口、队友快照、实例/历史/状态隔离、取消分裂、无死亡能力触发、原地回滚和真实Run奖励只结算一次。独立审阅另覆盖范围攻击边界。
- 生成控件验证三槽与五槽展开、真实子体点击伤害、死亡父体不可选、旧父体延迟触摸不可重定向、分裂说明及无反馈恢复。不是千星实机截图或鼠标/触控平台验收。
- 初始 b2ed 基线全部118份顶层原生Lua fixture通过。第一轮116/118，两个旧fixture中的四个 Down→Click 无Up序列暴露宿主兼容性回归，已修正而非删除断言；最终118/118。Lua5.4 ctypes运行器按项目需要提供 LUA_PATH 和 battle_ui 的真实布局注入。
- 初始 b2ed 基线定向JS154/154，另新/旧 Spike schema67/67；较大受影响集合449项中445过、4失败，均为缺少 `fengari-node-cli/src/lua-cli.js` 的已有桥接限制（UTF8实际Lua往返、六表载入、runner失败/超时和自动发现）。原生通过不替代Fengari检查，不宣称完整 npm check 通过。
- 最终2925合成在重新生成数据、主题、UI和地图布局后，全部119份原生Lua fixture通过、定向JS155/155、Python呈现17/17；较大受影响JS集合450项中446过，仍只有同四项缺失Fengari桥接失败。自带合成触摸回归4/4。
- 数据、主题和UI生成、地图布局生成、validate:data、JavaScript syntax均通过。没有平台构建/导入/实机，本片不关闭 TASK-15、M1/M3、完整第一幕、原版随机流或发布关口。

其他软泥的分裂、Slime Boss、窃金客、合法原版全遭遇分布、完整通用队列及各项平台证据继续各自保留，不能把本片当作它们的完成证明。
