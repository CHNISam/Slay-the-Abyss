# PR196 × PR197：能力门禁隔离集成核验

## 结论与适用范围

**风险成立：若将 PR197 当前能力门禁原样接入 PR196 已实现的 75 卡体系，Clash 与 Whirlwind 会被错误排除或拒绝升级/变换。** 已实际运行交叉模块，不是仅凭字段推测。

这不是任何单 PR 已存在的 bug，更不是主线回归或实际合并产物验收。最终远端复查时两 PR 均 open、未合并，base 均为 `9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db`。

- PR196：`824a5da106525a95e7a0e8cf5c1e8ec0b411123a`，Draft。
- 指定 PR197：`efd3feb7052d0a8f7b4b8410d8507a7e5584c556`。
- 实际 PR197 当前头：`6457b61f9f600178ad8279839243c82f52b772cd`。与指定头仅有 `tests/lua/card_pool.lua` 测试成本改动，全部生产模块相同；能力模块 Git blob 均为 `613f56b14f8e055d5a6eae8e6611ae6b7e1cea2d`。
- 读取了两头相同 blob 的 AGENTS、HANDOFF/SCOPE、TASK16/16.1 与原随机流/活墙 owner 说明。任务 assignee 为 `@Codex`，PR author 为 CHNISam。Backlog CLI 在本环境不存在；只读资料，未安装、未写任务库。

## 隔离方式

所有工作仅写本目录。原工作树、PR、Backlog、远端均未改动。

- 运行数据：PR196 的完整 6 个 JSON 数据文件，经该头原始 build-lua-data/validate-data 构建；重建输出与提供的生成 Lua 逐 byte 相同。
- 战斗、效果、完整卡池、Run、Map 及依赖：PR196 原模块。
- 被核验门禁：PR197 原始 `abyss_card_capability`，连同原 `abyss_nodes`、`abyss_shop`、`abyss_living_wall`、`abyss_transform_card`、`abyss_card_random` 在明确的调用边界加载。
- 营地对照使用同一真实购买后 Run 状态，分别调用两头原 Nodes，不覆盖 PR196 的完整 Run/奖励算法。商店对照使用 PR197 同一实现、同种子，只在进程内临时放行两张已证明实现的牌定位阻挡点。诊断开关不是正式修复。
- 原型安全对照独立进程只用 PR197 自身数据、战斗、效果与门禁。
- 最终逐 Git blob 验证：196 侧 68 件、197 侧 64 件源文件与冻结远端一致。无需安装、全量 npm 或 UI/平台运行。

## 实际结果

1. PR196 的 75 张 attack/skill/power 定义交给 PR197 门禁：73 张通过，只有 `clash`、`whirlwind` 被拒绝；二者的 `Effects.supported` 均为 true。
2. PR196 实际 Combat 执行：Clash 普通/升级造成 14/18 伤害，3 能量不变；Whirlwind 普通/升级在 3 能量时造成 15/24 伤害，能量归 0。不是只有定义或卡面。
3. 通过 PR196 公开商店入口真实抽样并购买，未修改牌池或库存：Clash seed=7、slot=2、53 金币；Whirlwind seed=16、slot=1、81 金币；新永久 UID 均为 11。随后同一营地状态，Nodes196 成功升级；Nodes197 均返回 `false, card_not_upgradeable`，卡未升级。
4. PR197 商店只改变诊断门禁这一变量：同 seed=7/slot=2，原门禁提供 cleave，诊断提供并公开买入 Clash；同 seed=16/slot=1，原门禁提供 sever_soul，诊断提供并公开买入 Whirlwind。证明错拒确实改变可获取池，而不是原随机流差异的猜测。
5. Living Wall 显式事件入口，保持完整 72 张源顺序池，选择槽 12 的 Clash、槽 40 的 Whirlwind：原门禁均 `event_content_unavailable`，牌组、UID、全部状态值及保留的牌组/RNG 引用未变；仅对目标卡作进程内诊断放行后，真实 `chooseLivingWallCard` 成功取得该牌，misc counter 从 7 到 8。没有缩池、重抽或提交失败流。此入口是显式事件夹具，不声称该事件已进入正常事件概率池。
6. PR197 原始安全对照：Clash、True Grit、Warcry、Metallicize、Whirlwind、Demon Form、Reaper 七原型均确被能力门禁及自身 Combat 拒绝。前两类标志牌报 `advanced_card_not_enabled`，其余为对应 `unsupported_effect`。因此原型拒绝的安全目的成立。
7. 交叉门禁仍拒绝 unknown condition、unknown costMode、unknown effect；合法登记的 Regret、Dazed、Slimed 仍通过。

商店/营地夹具使用真实连接路径，但跳过了前序房间的实际战斗，并显式提供精确购买金币。属于公共命令事务验证，不是完整自然 run、自然构筑或平台证据。

## 定位与最小接续建议

- 根因：PR197 `src/lua/abyss_card_capability.lua:7` 对 condition/costMode 无条件返回 false。
- 相应消费者：`abyss_nodes.lua:27-38`（升级）、`abyss_shop.lua:44-51`（商店）、`abyss_living_wall.lua:33-37`（变换）。PR197 `abyss_run.lua:178-185` 的旧奖励候选也使用该门禁，但本次没有把它覆盖 PR196 的完整奖励 owner，也不宣称实跑了该旧奖励流程。
- PR196 已实现：`abyss_combat.lua:360-364` 的 only_attacks_in_hand 条件，以及 `:423-447` 的 X 能量与次数处理；数据中二者分别保留 condition 与 costMode，因此会稳定命中门禁。
- 集成 owner 应把“已实现能力登记”与实际 PR196 实现同步，并在最终真正合并候选上回归普通/升级、临时不可打状态、公开获取/营地、完整池单次变换与原子拒绝。
- **不要直接删 guard，也不要用临时 canPlay（能量/手牌/目标）代替能力登记；继续拒绝未知 condition/costMode/effects 和未实现原型。** 不能泛 allow、缩池、跳过 unsupported 或重归一化后声称保持原版概率。
- 本目录不提供生产补丁，也未处理两头其它合并冲突、Searing Blow 重复升级、完整 RNG owner 接线或整池最终验收。

## 可复跑证据

在本目录执行：

```sh
python run-lua.py probe.lua
python run-lua.py prototype-control.lua
python run-lua.py transform-probe.lua
```

三组最终诊断均 exit 0，表示成功证明预期对照及真实错拒，**不表示集成缺陷已修复**。runner 复用系统 liblua5.4，不安装解释器。

完整输出：`evidence/final-probe.txt`、`evidence/final-prototype-control.txt`、`evidence/final-transform-probe.txt`。远端身份与验证：`evidence/final-pr196.json`、`final-pr197.json`、`197-head-delta.json`、`final-source-verification.json`、`sha256.txt`。抓取夹具首次额外尾换行被源 hash 门禁发现并在本目录纠正，最终逐 blob 复验通过；记录在 `fixture-materialization-correction.json`。

源码链接：
- https://github.com/CHNISam/Slay-the-Abyss/blob/6457b61f9f600178ad8279839243c82f52b772cd/src/lua/abyss_card_capability.lua#L7
- https://github.com/CHNISam/Slay-the-Abyss/blob/824a5da106525a95e7a0e8cf5c1e8ec0b411123a/src/lua/abyss_combat.lua#L360-L364
- https://github.com/CHNISam/Slay-the-Abyss/blob/824a5da106525a95e7a0e8cf5c1e8ec0b411123a/src/lua/abyss_combat.lua#L423-L447
