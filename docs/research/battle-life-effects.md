# 战斗技能表现类型 · 2026-10-30

本切片承接 TASK-29/29.1，只覆盖岩系旅行者第一、第二幕的表现。原有反馈已经区分普通、重击、多段、群攻、持续伤害与死亡；本次补充招式身份和效果语义，不再把所有非状态命中画成同一种金色闪光。

## 原版技术参考

读取本机已存档的 `sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0.zip`，没有再次下载。固定来源为[社区反编译镜像](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，不是官方认证构建，也未据此声称原版实机效果一致。下面哈希是解压后文件字节的 SHA256，代码不复制到产品中。

| 文件及位置 | 实际机制 | 本项目采用方式 |
| --- | --- | --- |
| [SlaverRed.java:77–97](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SlaverRed.java#L77-L97) | 束缚 VFX 在施加状态前排队；两种普通攻击分别选横斩与斜斩 | 按 `red_slaver/red_slaver_2` 选择束缚，不能仅凭伤害值判断；状态落地和攻击接触分别取样 |
| [Sentry.java:80–102](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/Sentry.java#L80-L102) | 扩散波与激光使用不同效果，激光 VFXAction 先于伤害动作；快速模式缩短等待 | 投射起终点由调用者提供，在原 intent 时间内绘制，伤害事件仍保持原位置 |
| [Chosen.java:99–133](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/city/Chosen.java#L99-L133) | 连续横/纵斩、火焰、重斩与 Hex 是不同分支 | `zap` 投射、`debilitate` 重击、`hex/drain` 状态束缚，实际状态事件可覆盖行动类别 |
| [SnakePlant.java:90–107](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/city/SnakePlant.java#L90-L107) | 咬击有独立颜色、VFX 等待和随机视觉偏移；孢子另施加弱化 | 保留孢子/毒液的上浮扩散语汇；不移植任何视觉随机数，也不让孢子获得原规则不存在的中毒伤害 |
| [AnimatedSlashEffect.java:42–62](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/combat/AnimatedSlashEffect.java#L42-L62) | 入场与出场两段，位移使用 fade，尾段透明度使用 pow5In | 归一化接触尾段使用 `(1-p)^5`；fade 的五次平滑曲线复用于投射位置。没有照搬原版贴图、混合器或随机抖动 |
| [EntangleEffect.java:23–44](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/combat/EntangleEffect.java#L23-L44) | 位置使用 pow5In；透明度与缩放独立于规则动作 | 束缚飞行使用 `p^5`，落地后收紧形状；原 bounce 缩放在低成本原生控件下改为平滑收紧，不冒称逐帧还原 |
| [SmallLaserEffect.java:27–49](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/combat/SmallLaserEffect.java#L27-L49) | 按真实起终点求长度和角度，透明度独立更新 | 投射物接触横向细长、二次衰减。起手投射与接触尾段分开，绝不在 HP 已下降后重演飞行 |

| 文件 | SHA256 |
| --- | --- |
| monsters/exordium/SlaverRed.java | `2e92dfad2ddee766d9f95b45c028b80b5abae3e966eb3dff1656d60c253da7c4` |
| monsters/exordium/Sentry.java | `5a3837cdf1b4ef4383fc7e1385c8c64a0c92bc04916c9c4f919d79080980acb2` |
| monsters/city/Chosen.java | `6680d25dbce1f9a25832df72b75c4a14fbb02e891389d5ffcda7ffd1df54bc38` |
| monsters/city/SnakePlant.java | `bde4d7cc2f541ab95c817a1e8230f3c309a3599c43f329fd50ac34d770b48186` |
| vfx/combat/AnimatedSlashEffect.java | `3deb3dfaab2170e9ed036bffb3acede85a37bedbafeb3bd3d7901513c1edd3bf` |
| vfx/combat/EntangleEffect.java | `5aea99b9fbaf0600b673303c95580b8275c2417731aec07df1720da9e9a2928e` |
| vfx/combat/SmallLaserEffect.java | `18e25dabcc311fddfc902e97ac0fba2d06ad31f46432b1eb2cb9918926e5330d` |

酸液软泥源码 `AcidSlime_M.java:80–101` 只显示慢攻击和重钝击，不能据敌人名字把每招声称为原版毒弹。本项目只把实际酸液弱化意图选为毒液表现，伤害和状态文本仍读真实事件。第二幕 `collector/fireball`、`automaton/hyper_beam`、`bronze_orb/beam` 等是对本项目实际意图的演出适配，不声称本轮逐个核对了这些原版类。

## 接口与集成

`abyss_skill_feedback` 无平台依赖、无 RNG、无状态写入，也不分配控件。新增模块须在 `config/architecture.json` 登记 UI 层，由中控统一改配置。

- `resolve(kind, detail, context)` 返回 `melee/heavy/projectile/poison/bind/buff/defend/dot/none`。context 读取 `enemyId`（definitionId）、`intentId`、`intentKind`、`effects`、继承 `family`、`weight`、实际 `statusKind`。ID 必须同时匹配，绝不以实例编号、名字子串或单独 `fireball` 误匹配。
- `sample(family, progress, span)` 返回 `sx, sy, x, y, alpha, themeColourKey`，供既有 `impact` 控件在接触后绘制；现有 `Theme.space` 提供 span。八类具有不同形状/上浮/透明度曲线，p=1 全部透明，采样不创建对象。
- `travel(family, progress, sourceX, sourceY, targetX, targetY)` 返回 `x,y,alpha`。在既有 play/intent 区间内复用固定 sweep 或现有覆盖层控件，起终点用真实单位坐标；p=1 隐藏，再进入真实 damage/status 接触。不要新增延迟动作或重复消费事件。
- `cue(family, kind, detail)` 只返回已有 `hit/hit_heavy/block_hit/status/block_gain/heal`，供替换旧选择器；不要叠播。原有玩家 `hurt`、起手声、死亡声与群攻/多段去重仍归现有队列所有者。没有未经核实的音效编号，没有拿动作声冒充荧语音。

最小接线：classify 创建 play/intent context 时填实际身份与 effects/intentKind，逐个目标事件用 resolve 填 style.family（实际状态类型从 catalog 查）；targetStep 储存 style；paintImpact 保留现有 show/窗口/图标判断，改用 sample 返回形状及 Theme.color 颜色。投射 travel 必须挂在进入 play/intent 时建立的既有视觉时钟，目标为下一条同来源真实 damage/status 目标，在接触前结束，不改变 action gate。

## 验证与限制

先写独立测试，缺模块时实际失败；模块加入后 `tests/lua/skill_feedback.lua` 通过54项断言并遍历本项目第一、第二幕120个真实意图，睡眠/眩晕/逃跑保持无效果，其余意图有表现类型。还覆盖ID不误匹配、真实状态覆盖、多段重击不误变投射、八类不同轨迹、结束透明、负/超范围进度、旅行起终点、100次重复确定性、禁止随机函数以及输入对象不变。

验证命令：`node scripts/test-lua.mjs tests/lua/skill_feedback.lua`。本机沙箱内标准 runner 的子进程曾被 EPERM 拒绝，直接运行同一 Fengari CLI 的 `-e dofile(...)` 通过；应由中控在允许子进程的标准环境再次执行。`npm run build:data` 与 `npm run build:theme` 成功。

这是分类/采样模块的离线证据；统一 Feedback 接线及生产队列测试由中控集成后追加。尚无本轮官方导入、原生ready、PC/实体手机性能、画面和实际声音证据，不能把纯采样测试称为实际可玩验收。
