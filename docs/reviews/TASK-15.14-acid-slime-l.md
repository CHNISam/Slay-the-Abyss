# TASK-15.14 · 大型酸液团的非分裂三招

## 有限修正

基线 `3a984f9a603093d9d9c9111138d3bfcaecbea176` 的 `large_acid` 遭遇直接生成大型酸液团，但当时固定68生命、11伤害与虚弱2交替，没有污染牌、普通16伤害或选招随机请求。本片只修普通生成与非分裂行动，保留现有中文名称、美术和卡牌文案，不扩充遭遇池。

- HP按65–69闭区间采样，开场主roll先于洗牌。
- 酸蚀攻击：伤害11，随后弃牌堆加入2张临时Slimed，再选下一招。满格挡仍塞牌。
- 普通攻击：伤害16，不塞牌。虚弱行动：施加Weak2。
- 主roll为0–99；0–29选酸蚀，30–69选普通攻击，70–99选虚弱。前两次都是酸蚀时，低区间额外无参数Boolean，true改普通攻击，false改虚弱；上次为普通攻击时，中区间额外概率Boolean，成功改酸蚀，否则虚弱；前两次为虚弱时，高区间额外概率Boolean，成功改酸蚀，否则普通攻击。
- 概率参数为源代码`0.4f`的精确binary32值 `0.4000000059604645`，严格小于。仅必要历史回退才消耗额外请求。无参数Boolean和概率Boolean不混用。
- 各个非分裂行动末排队一次RollMove。活队友仍在时，荆棘反杀不删除已经排队的污染牌或主roll；末敌死亡、玩家死亡和行动前毒杀保留既有队列规则。

大型和中型源码的A0 `getMove` 分支逐字一致，因此仅在 `abyss_enemy_ai` 初始化/推进/排队白名单接入已有 `abyss_acid_slime_m_ai`，没有复制算法或修改该模块。数据校验共享三招结构，但分别严格要求中型Slimed1与大型Slimed2。未修改Combat、Actor、Inventory、battle UI或卡牌预览。

## 固定来源

只读来源为社区CFR反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方源码、正版PC JAR的hash认证或客户端观测。每份原始UTF-8字节均复算Git blob，并与固定来源API返回值核对；第三方Java不随本改动提交。

| 文件与固定链接 | Git blob | SHA256 |
| --- | --- | --- |
| [AcidSlime_L](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/AcidSlime_L.java) | `274b3d4be405c9aaedda6c2e3aaaa22abff0165d` | `56eaec2de1c6344701613e5643f3161c5acf6591890b7859f062f420a692dd72` |
| [AcidSlime_M](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/AcidSlime_M.java) | `b8d5ee4d71b7084624a19b73cf0c7b4df38a54d0` | `34fe1c1000d351ffd3ee1e5902a0af14ebb10fe3885bd181feeb75c1942cb400` |
| [Random](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java) | `c4b71d5645688f6e764c46c593223eb91a5249bc` | `476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172` |
| [AbstractMonster](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [RollMoveAction](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RollMoveAction.java) | `01731f966b9b6f8c3815b246cd02cf75eb5d2153` | `c938d4b4a9183b39e91c1c54c79085ddf7b2bea082af14895b9a1a00a100fc50` |
| [MakeTempCardInDiscardAction](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MakeTempCardInDiscardAction.java) | `f4f3cc0d88d8c4124ef070ccb9e0852c3cfc83f7` | `78eeca2eeeaf22de9146148cdcb015b7bdd335f0529a6f62fdadba3dd4d28efd` |

构造和`takeTurn/getMove`提供HP、数值、顺序和分支事实；`AbstractMonster.init/rollMove`提供开场0–99请求；`Random`区分nextBoolean与nextFloat比较；两个Action分别核验无敌人死亡guard的roll与临时牌复制。共享末敌/玩家死亡队列沿用TASK-15.12和TASK-16.1.2已合规则，本片未扩展接口。

## 实际离线证据

- 初始独立23组真实Combat/Run探针为20红、3死亡负控绿，明确暴露固定HP、错误首动/历史、无污染牌/普通攻击和缺主roll。
- 最终Lua测试29组在原基线复验25红、4绿，修复后29组全绿。13种历史×100主roll×2回退结果共2600次真实运行时验证决策、额外抽样类型/次数；另测HP端点、效果顺序、格挡/Artifact、死亡队列、多实例、回滚和Run临时牌生命周期。中酸21组保留通过。
- 31项新增schema测试在原基线29红、2既有约束绿，修复后全绿；与中酸24项合计55项全绿，覆盖非法概率/动作引用/未知字段与缺牌、错牌、错序、错数量，不放宽中型约束。
- 从固定Git树逐blob物化全部src34/data13/scripts43/tests227/backlog129个文件，再增加本片测试。完整原生Lua共125文件全部退出0，包含18遭遇/23敌人/56意图的60组覆盖；宿主为Lua5.4，不等同生产Fengari或千星运行时。
- 相关31个JS测试文件501项全部通过，无跳过；Python发现并执行17项全部通过。build:data、build:ui、地图布局、build:theme、validate:data与JavaScript语法检查通过。
- 首次扩大Lua运行因本快照缺工具脚本及生成主题等有43个启动/fixture失败；补齐同SHA工具并正常生成后全125文件重跑通过。历史矩阵首次把回合后抽牌洗牌混计为AI调用，改用保留抽牌堆的隔离夹具后复验；未修改生产随机规则或降低断言。
- 未安装Fengari或执行完整npm check；准确发布SHA的正式Quality与独立审查结果以对应PR为准。原始日志和冻结文件hash已交协调者，不将部分离线检查称为完整CI。

## 保留边界

大型酸液团的半血中断与分裂仍未接入；行动时剩余HP、子体生成/初始化/行动顺序需要单独来源核实与共享核心认领。本片绝不是完整大型酸液敌人验收，父任务TASK-15继续保留。

生产随机仍为项目共享LCG，Boolean两值适配、概率16位格点不等于原作RandomXS128/nextFloat24位和独立随机流。新增HP与AI抽样会改变项目后续随机轨迹；仅声明受控输入下非分裂决策和调用顺序，不声明精确总体概率、同种子整局或PC构建一致。未开游戏/MCP、编译平台副本、官方导入、写存档或实机，所有平台关口不关闭。
