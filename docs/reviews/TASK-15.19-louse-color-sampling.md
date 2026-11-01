# TASK-15.19：双甲虫和三甲虫逐槽配色

2026-10-24。实现基线为 develop `d18d511c6814bb19f975bd95e16c34cb9472ee57`，任务认领头为 `a7e37feae381443aac0d197da69be548e6175509`。本次仅验证既有初代 PC A0 规则契约下的颜色组装，不是整局随机流或平台验收。

## 固定来源

行为依据是社区 CFR 反编译镜像 [aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，不是官方开源源码，也未通过正版 PC 发行二进制 hash 认证。原文只作独立研究参考，没有复制到游戏代码。

- [MonsterHelper.java L415–419](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java#L415-L419)：双/三甲虫分别按槽调用两/三次 getLouse；[L825–829](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java#L825-L829) 每次从 miscRng 取一个 Boolean，true 为 LouseNormal 赤甲虫，false 为 LouseDefensive 青甲虫。Git blob `a81763abf681642be66cbd935cc99d2126e822f4`；SHA256 `e6a60cdfa7af881d5f128a9532664ea33f32e71239cda49f3983fceac95a10e1`。
- [Random.java L74–76](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java#L74-L76)：每次 Boolean 的 counter 加一。blob `c4b71d5645688f6e764c46c593223eb91a5249bc`。
- [MonsterGroup.java L26–28](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java#L26-L28)：保留传入数组顺序，没有颜色组装后的额外洗牌。blob `7096970a151840489a3fba89806e6391e0d82d76`。
- [LouseNormal](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/LouseNormal.java#L45-L66) / [LouseDefensive](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/LouseDefensive.java#L48-L69) 分别构造自身 HP、Bite；blob `f56e24b37816f256bd058184c1b54a49584092a7` / `83dc2dad1247ef33c5ef76ec5ca5cdbc5ced8def`。

双虫有序支持集为 GG、GR、RG、RR，各 1/4；三虫为 GGG、GGR、GRG、GRR、RGG、RGR、RRG、RRR，各 1/8。忽略槽位后红色数量的重数分别为 1:2:1 与 1:3:3:1。固定 RG/RGR 仅是各支持集中的一个结果，不能代表完整分布。

## 实现边界

仅 `louse_pair` / `louse_trio` 使用 `lousePool=[red_louse,green_louse]` 和 `louseCount=2/3`，没有静态 fallback。Run 在现有 misc 克隆上逐槽取 Boolean，不删除候选、不强制混色、不额外洗牌；成功完成真实 Combat 构造、开场前效果及开场尾部后才提交新流。失败不替换原流或地图，重试使用同一原状态。

保留现有小软泥 Boolean 分支、小魔带重复权重的无放回四槽池。没有修改 Combat、Nodes、AI、RNG 算法、HP/Bite/Curl Up、卡牌数值、UI、主题或测试预算。低层显式 Combat 敌人数组仍照原样构造，不隐式变色。

原源全局调用顺序是颜色1 → 敌1 HP/Bite → 颜色2 → 敌2 HP/Bite → …，全部构造后再逐敌初始化 AI。本项目颜色 misc 与 Combat 的 HP/AI/洗牌流独立，因此先在 misc 克隆取完颜色不会改变每条流内部顺序；但当前 Combat 仍使用共享 LCG，尚未拆成原版 monsterHpRng / aiRng / shuffleRng。此前 misc 消费与原 PC 种子映射、完整原版流、普通遭遇池权重/楼层队列均未在本任务认证。

## 消费者检查

- `scripts/validate-data.mjs`：限制两个 ID、精确有序池、对应 2/3 次数，拒绝静态/双变体/小魔字段混用；继续检查敌人 ID、tier 和包含分裂父体的五槽容量。重复可选池按最大候选占槽乘组大小检查，不把两候选当两名敌人。保留 PR181 的 targetGroup 校验。
- `scripts/verify-launch-content.mjs`：比较 lousePool/louseCount；敌人渠道用静态、双变体、小魔池、甲虫池的并集。首发 JSON 与文档同步，两色原有合法渠道不变。
- `abyss_map.lua` / `abyss_nodes.lua` 只依赖遭遇 ID、层级和楼层，不依赖固定 enemies，未修改。
- `scripts/audit-encounter-pressure.lua` 原本已从真实 `run.combat.enemies` 取人数，无须改写。诊断执行成功，双/三虫实为 2/3 名。它是不出牌压力观察，不是玩家难度或平衡验收。
- 全仓相关引用另覆盖 build 数据、首发 Lua gate、真实资源审计和遭遇覆盖 fixture。原 `louse_ai.lua` 的 Strength3/Weak2 断言完全保留，仅控制颜色 Boolean 为 T/F，继续测真实红青 AI。小软泥、小魔与遭遇覆盖的 seed42 字面预期更新为 T,T,F → RR/RRG；没有删除它们的整状态回归。

## 先红后绿与回归证据

- 原审查 94 项在最新基线复现：46 过、48 失败；实现后 94/94 通过。不是 48 个不同缺陷。
- `tests/lua/louse_colors.lua`：273 项通过。12 种纯选择分支只截取真实 Run 传给 Combat 的数组，不重复构造战斗/UI。少量真实 Run 入口保留 HP、AI、洗牌和 Curl；普通与问号 Nodes 入口计数精确为 2/3，event 仅保留其本来的未知房判定消费。
- 构造返回 nil、构造抛错、开场前失败、开场尾部失败，共 6 个入口 × 4 类 = 24 组；验证整个 run/map 的原引用和值不变、尝试仍按槽消费暂存流、成功重试的颜色/流/完整状态等于干净首入。只查看和重复进入不消费。
- 其他 16 个遭遇完整 roster、真实 Combat 状态、misc 状态与引用回归全部通过；显式低层组不抽颜色，同色演员的实例、状态和招式表独立。
- `tests/louse-colors-data.test.mjs` 41 项、`tests/louse-colors-launch.test.mjs` 15 项先红后绿。覆盖错 ID/池/顺序/数量/引用/tier/容量、静态与变体冲突、清单漂移及遗漏渠道。
- 9 个独立负变异均被测试杀死：反转颜色、固定红、全组只抽一次、直接修改原 misc、漏末槽、反转槽顺序、提前提交、额外 Boolean、无放回抽样；恢复原实现后对照全绿。
- 串行运行 172 个 native Lua 文件全部通过，包括 game_ui、Curl Up、BGM、Shockwave、Barricade、小软泥、小魔和遭遇覆盖；首发真实 Lua gate 通过。首轮验证进程漏设 LUA_PATH 导致 15 个文件及 gate 找不到模块，失败日志保留；修正验证环境后完整重跑，没有改生产文件掩盖问题。
- 直接 Node 内置测试的纯 Node 子集 1141/1141 通过；全量 Node 调用实际为 1259 项，1181 过、78 失败，全部失败逐项核对为未安装 `fengari-node-cli`。没有安装依赖或用 native Lua 冒充 Fengari，这一全量调用不能记为 check 通过。
- Python 22/22；数据验证、JavaScript 语法、Backlog 检查与 data/UI/theme 生成均通过。只更正 JSON 排版后解析内容全等，重新生成并重跑 56 项 Node 和 273 项 Lua 通过。

## 自然路线与平台分层

使用既有 `scripts/m2-resource-audit.lua` / `m2-autoplay-policy.lua`，实际 Run/Nodes 进入、出牌、奖励、营地与商店；无 Map.choose 跳过、无改 HP/金币/牌组/数值、无强制胜利。

- seed0：17 层正常结束，26 HP；第4层三虫 RRR。
- seed7：17 层正常结束，35 HP；第2层双虫 GR、第10层双虫 RR。
- seed21：17 层正常结束，22 HP；第1层双虫 GR、第2层双虫 RG。
- seed42：第6层精英处真实败亡，0 HP；前两场双虫已自然进入。保留失败，不把挑出的成功种子当作普遍难度结论。

以上是原生 Lua 5.4 离线证据，不是 Fengari、千星编译、写副本、官方导入、原神实机或手机验收。实现者阶段没有用户 Codex 调用、安装、远端写入或发布；CI、独立评审和最终整合由主任务另行记录。费用及额度节省未知。

## 集成边界

2026-10-25组合核对：当前正式地图已由source formation逐槽抽色，本旧候选仅补齐legacyData显式遭遇的同一规则；startEncounter严格在not sourceRoom时抽色，避免正式入口消费两遍。机器清单及负例迁移到legacyData.encounters，正式绑定、formation traces、75卡与事件/道具生产门禁原样保留。旧入口回归以本轮实际组合结果为准，下述旧基线与规则待决文字作为历史保留；当前规则仍固定SCOPE中的初代PC A0。

本候选按既有初代A0合同核验。Owner关于规则基准是否切换二代仍待确认，因此暂不合并，不修改SCOPE。以上自然路线与运行证据固定d18d511c/认领a7e37fea，不含在途PR182的开局seed、格挡和显式领取药水变更，不能认证其组合；并集须另核全部入口和新奖励推进。
