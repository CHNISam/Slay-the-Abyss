# 黑星：生产定义与现代源宝箱取得

2026-10-28接续集成补充：原树未提交的奖励计数修正已接入。源房间在药水概率抽样前按金币、失金、遗物和独立绿钥匙计算实际奖励项数；黑星双遗物加绿钥匙达到四项时仍消费一次概率掷骰，但不抽药水身份，即使白兽雕像保证掉落也保留该上限。未标记精英的三项情况正常掉药水。专用回归保留两次独立遗物抽样、完整来源RNG和失败原子回滚；本地受控验证不代表自然或平台通过。

本切片补充 `black_star` / `Black Star` 的 Boss 稀有度生产定义，使用既有
`hooks`、空通用 effects。校验器仅登记该已实现 hook ID，未知 hook 和非空
generic effects 继续拒绝。原 `RelicRewards.elite`、概率、完整源队列和战斗逻辑
均未修改；旧 `Inventory.bossEligible` 三件白名单也未修改。

## 固定来源

档案：`.artifacts/sts1-fixed-source/sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0.zip`。
所有 member 以 `sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0/` 为前缀。

| member | SHA-256 |
| --- | --- |
| `relics/BlackStar.java` | `74308ad3606083cb7055b0b508fadd523e77934a7a9824342a473371ce233f0e` |
| `rooms/MonsterRoomElite.java` | `c5207d745f383e1de615e613da8e5c8f832e237444c3b757d85a61f8b3f5ee3f` |
| `rewards/chests/BossChest.java` | `bad4fa7b36ffe2662030b6310414bbd5a5dc5108e2ff432f0322b262075b221a` |

原版 BlackStar 在精英房显示提示，实际奖励由 MonsterRoomElite.dropReward 负责。
精英先独立投第一次稀有度（0–49普通、50–82罕见、83–99稀有）并取遗物，
持有黑星时再独立投一次稀有度，并取非营火遗物；额外遗物排除 Peace Pipe、
Shovel、Girya。普通战斗不获得遗物。绿钥匙是独立奖励，可同时领取两件遗物。

BossChest 从真实 Boss 源队列产生三选一，现代 Nodes source chest 经公开
claim/Run.obtainRelic 取得生产定义。campaign 的现代宝箱存在于17和33层；
本切片覆盖17层取得后进入第二幕，不宣称旧显式三 Boss 奖励入口已支持黑星。

## 离线证据与边界

`tests/fixtures/black-star-oracle.py` 是独立 Python 固定源码解释，采用精确整数
XS128 和 Java48/Collections shuffle，读取完整 pinned source catalog，不导入
生产选择逻辑。seed144 的三 Boss offer 是 Astrolabe、Tiny House、Black Star。
初始化五次源 shuffle 后 counter=5，后续精英两次 tier roll 为74和94；普通奖励
是 Toxic Egg 2，额外奖励跳过 Peace Pipe 后得到 TungstenRod，counter=7。
夹具对两个完整 RNG snapshot、来源身份、tier 和 skip trace 逐项断言。
catalog 的顺序仍是已锁定 host JDK17 HashMap 顺序，并非已认证 PC 二进制顺序。

真实 RED：缺少生产定义时 `BLACK_STAR_PRODUCTION_DEFINITION_MISSING`，约199ms。
首次 GREEN：生产定义后 Node 3/3，总3.440s；其中公开 Run/Nodes fixture 3.250s。
夹具通过公开 BossChest 选择第三件取得黑星，随后真实正常房与绿精英构造、结算、
两件遗物领取及独立绿钥匙领取。没有直接塞入 owned 黑星、伪造 definition、缩减
完整源目录或替换源队列。Boss 获得后晚抛错及精英双遗物抽取后 Potion 准备晚抛错
均验证全图内容回滚和关键原引用保留，拒绝重复领取。

最终独占串行复验：`node --test --test-concurrency=1 tests/black-star.test.mjs tests/launch-content.test.mjs`
26/26 GREEN、37.332s，其中专用公开路径2.850s、两个完整runtime拒绝负例合计16.400s，
原清单22组全部保留且通过（真实生产runtime门禁9.451s）。每次Lua仍为原30秒预算。
输出保留在该工作树 ignored `build/black-star-final.log`。

原清单Lua门禁假设所有Boss都走旧三件谓词，新增定义曾真实触发
`Unobtainable Boss relic: black_star`。修正仅为唯一 `black_star` 分支：强校验
Boss稀有度、精确source ID、固定source commit、五tier完整大小及Boss22身份顺序，
再运行本切片真实宝箱取得及后续精英夹具。其他Boss仍走原强校验。完整负例确认
错误黑星source映射、陌生Boss仍拒绝；schema未知hook、非空通用effects也仍拒绝。

受控部分：跳过前序地图战斗的合法导航；将真实构造的敌人 HP 置零形成结算边界；
第二幕绿精英资格使用受控账号历史。以上是本地生产接线与规则证据，不是自然全程
通关、自然获得/执行、原版 PC 执行或千星实机/UI验收。TASK14.1完整遗物池仍未完成。

复验：先 `node scripts/build-lua-data.mjs`，再串行运行
`node --test --test-concurrency=1 tests/black-star.test.mjs`；完整清单门禁为
`node --test --test-concurrency=1 tests/launch-content.test.mjs`。

## 门禁实际输入绑定修正

父审查发现首版门禁检查 `LAUNCH_DATA`，但被调用夹具通过 `require('abyss_data')`
另取已生成数据，导致公开取得证明可能没有验证本轮输入。新增反例只将本轮稀有队列
`TungstenRod` 换成 `FakeRare`，保留sourceCommit、所有tier尺寸及Boss22完整身份，
旧门禁竟返回0。该反例真实RED为9.220s，错误为“corrupt supplied rare catalog
must not be validated against generated abyss_data instead”；原始日志为
ignored `build/black-star-source-binding-red.log`。

最小修正：专用夹具允许可选Data实参，直接运行仍回退到原 `require('abyss_data')`；
门禁用 `assert(loadfile('tests/lua/black_star.lua'))(data)` 传入本轮 `LAUNCH_DATA`。
这是与同脚本其它 `Run.new(data,...)` 相同的原始bundle，没有替身、重抽、改概率或
规范化替换。黑星另强校验 `trigger=='hooks'` 且effects表实际为空，其他Boss仍按原
谓词校验。新增runtime负例分别拒绝坏稀有目录、错误trigger、非空通用effects，
原有错误source映射和陌生Boss负例保留。

本轮同一完整串行命令最终 **28/28 GREEN，61.865s**，包含原清单22项和专用6项。
实际公开取得路径2.892s；相同坏rare输入修后被拒绝9.186s；source/陌生Boss两个负例
合计16.820s；错误hook/effects两个负例合计15.046s；生产清单runtime门禁9.442s。
每个Lua进程仍为原30秒预算，无超时。最终原始输出在
`build/black-star-source-binding-green.log`。未修改共享核心、生产规则或概率，
自然/原版PC执行/平台验收边界仍与上文相同。
