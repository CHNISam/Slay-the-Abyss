# TASK-85 · 雷电 V4 独立离线验证（2026-11-03）

## 结论与身份

本轮离线切片完成：新增 **8 组契约**（2 个 Node 子测试），复用的 **7 个现有 Lua 入口全通过**；3 个独立进程内负对照均被指定断言拦截。未确认生产缺陷。

- 执行者：OpenCode，负责人保留 `@Furinya`；认领来源 PR479 评论6597919043。
- 唯一工作树：`F:\New folder\.worktrees\raiden-v4-verification-20261103`。
- 分支：`feat/raiden-v4-verification-20261103`；历史取证基线 HEAD：`013535ae48198bd72616224a4729f90bb187ecd9`，原始输入为该脏树当时字节，不冒充后续集成 HEAD。
- 环境：Windows，Node `v22.22.1`，npm `10.9.4`；Node 实际路径 `C:\Program Files\nodejs\node.exe`。
- 依赖直接从根 `F:\New folder\node_modules` 解析 `fengari` / `fengari-node-cli`；无需安装。
- 证据：本轮脏树的真实 Lua/Fengari + mock 原生控件；不是官方 LuaHost、导入或自然两幕实测。没有 Git 提交/推送/PR/合并。

冻结输入保持原始字节，重放器先校验：

| 文件 | SHA256 |
| --- | --- |
| `data/original_v4/cards_v4.json` | `89229cdd7f6c1640d47bca95338f5e7887fbfd8720af181f7561d6eb45a45fca` |
| `data/original_v4/rules_v4.json` | `a100f8b0fd61e3724f0eda5e077055f82bcacb7a4536d337096d9a6389419c8e` |

## 覆盖差异与选择理由

| 合同 | 原有覆盖 | 本轮增量 / 复验 |
| --- | --- | --- |
| 600 牌面、1200 结算向量 | `original-v4-runtime.test.mjs`、冻结生产向量及 `original_v4_*` | 已交付矩阵不重跑、不重写；只运行小型 `original_v4_contract.lua` |
| 原始10牌首战、领奖、下一战 | `original_v4_acquisition.lua` | 原样复验；雷电 seed=1，首战3回合9次出牌、HP=71，领奖后11牌进入第二战 |
| 愿力公开路径 | 原有 Combat 级 Q 与下一回合返能合同、自然首战 E | 新增真正 `Run.play` 付费指令每回合最多2、累计最多6；重复命令无作用、冲突拒绝；每回合真实付费、抽牌、洗牌 |
| 雷眼与一心连续交互 | 原有孤立资源夹具与 E 的 UI 点击 | 新增同一个公开 Run 的 E→跨回合积愿力→Q→两次普攻；首次建眼不追击、刷新命中消耗旧眼；Q花3造成16+2；普攻11+9，一心只返下回合1能量；两结束阶段失效 |
| 预览只读 | 原有 HT 的单次 Combat 预览、通用卡面/UI | 新增 RD Q 连续3次预览及一心普攻预览；逐边比对**整个原始 Run 图**，含对象别名、牌堆、命令账本、RNG、旧事件帧、目录/规则，而非少数字段 |
| 失败无副作用 | 通用 Run/Combat 快照合同、HT付血拒绝 | 新增 RD 无愿力/坏目标/能量不足拒绝；Q和一心普攻**由雷眼实际消耗次数完成击杀，在真实奖励准备后**分别拒绝/抛异常的4组晚失败，愿力/雷眼/一心、完整图与双方命令账本回滚；同ID重试一次提交、再次重放无副作用 |
| 完全格挡 | 孤立卡牌/共享伤害层 | 新增一心强化9伤被9格挡完全吸收：消耗1次一心、不触发雷眼、不返能；随后真实扣血才触发 |
| 回合及下一战清理 | `original_v4_lifecycle.lua` 和自然跨节点 | 新增先真实产生愿力/眼/一心/延迟返能再验证失效及下一战资源归零，永久牌UID与Run命令账本保留 |
| 第一幕→第二幕身份、永久UID、库存 | `original_v4_lifecycle.lua:170-240` 已覆盖四角色 | 原样复验：角色资料/冻结数据、升级/UID、金币、遗物、药水、计数、命令账本保持；新战重置资源；旧章节遭遇检查点拒绝。该夹具布置Boss箱边界，并非自然通关 |
| 正式入口保持关闭 | `competition_roster_run/ui/prepared_ui.lua` | 原样复验：直接工厂、预处理数据绕过、原生控件/直接配置/手柄/过期确认均拒绝；full-source 显式开发雷电仍保留 |

新增夹具复用真实 `Run.new/startCombat/play/endTurn/finishCombat/leaveCombatRewards` 和 `Combat.cardPreview`。数值预期直接来自冻结 RD 规则及 RD2-001/003/004 文本，不复制生产机制。夹具仅布置五张合法永久牌、耐久静止敌人和致死/格挡边界；没有直接灌入愿力、一心、雷眼或额外能量。受控构筑不冒充自然获取或平衡证据。

## 精确执行与耗时

所有命令的 cwd 均为上列唯一工作树。下表时间为收据记录的子进程墙钟毫秒；每行均 exit 0、fail 0、skip 0。Lua 用例按自己的标记统计，不混为 Node 子测试数。

| 精确命令（`node` 为上述当前运行时） | 耗时 ms | 结果 |
| --- | ---: | --- |
| `node scripts/build-lua-data.mjs` | 130 | PASS |
| `node scripts/build-ui.mjs` | 894 | PASS |
| `node --test --test-concurrency=1 tests/raiden-v4-verification.test.mjs` | 21853 | 最终加强版：Node 2 pass / 0 fail / 0 skip；Lua 4公开路径+4回滚组 |
| `node scripts/test-lua.mjs tests/lua/original_v4_contract.lua` | 4268 | PASS 19组 |
| `node scripts/test-lua.mjs tests/lua/original_v4_acquisition.lua` | 7667 | PASS 4角色 |
| `node scripts/test-lua.mjs tests/lua/original_v4_lifecycle.lua` | 9838 | PASS 4角色生命周期及4角色跨幕 |
| `node scripts/test-lua.mjs tests/lua/original_v4_cards.lua` | 10781 | PASS 4角色真实Host点击/回合 |
| `node scripts/test-lua.mjs tests/lua/competition_roster_run.lua` | 4095 | PASS 4组 |
| `node scripts/test-lua.mjs tests/lua/competition_roster_ui.lua` | 2764 | PASS 原生mock控件/直接配置/手柄/过期确认 |
| `node scripts/test-lua.mjs tests/lua/competition_roster_prepared_ui.lua` | 10558 | PASS 18组 |
| `npm run verify:backlog` | 566 | PASS 任务范围、编号、负责人和优先级 |

`node --check tests/raiden-v4-verification.test.mjs`、`node --check docs/evidence/raiden-v4-verification-20261103/replay.mjs` 与 `git diff --check` 也均 exit 0（未单独计时）。交付路径共10个，见文末。

最终加强版 stdout/stderr、UTC、退出码、当前测试/关键源码SHA在 [results.json](../evidence/raiden-v4-verification-20261103/results.json)。既有7入口和必要构建原始结果在 [results-initial.json](../evidence/raiden-v4-verification-20261103/results-initial.json)。初轮普通构建/测试10个子命令全绿；该初轮收据顶层 `FAIL` 是负对照诊断匹配错误，完整保留，不能当作生产失败或改写成绿。最终收据关联初轮的SHA，明确唯一变更输入为加强后的回滚测试；没有复跑无变化的7入口。

### 独立负对照

使用当前真实模块，在**各自新启动的 Fengari 进程**临时包裹一个函数；不写生产文件。未变更测试断言、时限或冻结输入。

| 单一退化 | 指定断言证据 | 后续耗时 ms | 结果 |
| --- | --- | ---: | --- |
| 不清零每回合愿力获取数 | 第二回合应R=4，实际R=2：`expected 4 got 2` | 2459 | EXPECTED_RED，exit 1 |
| 预览偷扣真实雷眼次数 | 完整原图边 `uses: expected 2 got 1` | 5816 | EXPECTED_RED，exit 1 |
| 晚失败回滚残留愿力99 | 完整原图边 `resolve: expected 3 got 99` | 1965 | EXPECTED_RED，exit 1 |

最终精确 `-e` 参数、栈与收据关联见 [results.json](../evidence/raiden-v4-verification-20261103/results.json)。较早一次修正匹配后的记录另保存在 [negative-controls.json](../evidence/raiden-v4-verification-20261103/negative-controls.json)。负对照重放器本身 exit 0，3/3 kill，无survivor/skip；通过不依靠“任意报错”，必须非零且命中指定断言诊断。

### 重放入口

```powershell
# 从指定工作树运行；完整重放只涉及本切片，不是全量 check
node docs/evidence/raiden-v4-verification-20261103/replay.mjs

# 以下两参数仅用于原始013535ae脏树的历史诊断；当前提交使用上面的完整入口。
# 原始测试布局保存在源切片提交22b75e9b；迁移后不复用历史SHA为当前通过凭证。
# 历史诊断匹配修正后仅重跑负对照：先核对既有绿基线及全部记录输入SHA未变
node docs/evidence/raiden-v4-verification-20261103/replay.mjs --negative-only

# 历史末次加强雷眼回滚边界：只重跑新增测试和负对照，引用未变的既有7入口
node docs/evidence/raiden-v4-verification-20261103/replay.mjs --focused
```

当前完整/聚焦重放写 `build/raiden-v4-verification.json`；负对照重放写 `build/raiden-v4-negative-controls.json`，各自包含新时间和原始输出；已提交的历史收据保持原样。历史初轮入口曾写证据目录，执行历史版本时须用独立副本。开发期红例、探针与纠正见 [development-history.md](../evidence/raiden-v4-verification-20261103/development-history.md)。本轮完整重放88.361秒（首次匹配错误 exit 1）；匹配修正重放9.573秒（exit 0）；最后加强边界后的聚焦重放32.131秒（exit 0）。

### 集成前独审修正

独立审查 `OpenCode-gpt-6.1-sol-9450b8af-50d5-4a27-ae2a-07570e988d00` 发现 Windows 默认检出将新增LF输入/收据改为CRLF，历史收据链的原始字节因此失配。通过现有 `.gitattributes` 固定新增收据与测试的LF字节；原始收据、失败记录与hash不改写。当前原始路径与字节可从源切片 `22b75e9b` 取回。

两份Lua合同随后移到 `tests/lua/support/`，由唯一Node入口在Windows/POSIX调用，退出顶层raw Lua自动发现，保留全部8组断言并消除同平台重复执行。公开命令合同内容不变；回滚合同只更新共享夹具路径，Node与重放器同步路径。历史收据继续描述原布局，不能用历史路径/hash认证新布局。

## AC 与后续验收

TASK-85 保持 **In Progress / @Furinya，6项AC全部未勾**。本轮只证明所列离线合同，不能将AC4“逐项验证”概括为全部交互已验。

| AC | 本轮能证明 | 未完成 |
| --- | --- | --- |
| 1 V4机制与设备 | 所列公开路径离线合同 | 完整可玩与真实设备 |
| 2 两幕构筑/奖励/跨幕 | 既有首战自然领奖、隔离渠道和跨幕边界复验 | 两幕逐项自然验证 |
| 3 自然获取连续战斗 | seed1真实Lua首战→领奖→下一战 | 官方实机证据 |
| 4 资源交互/回滚逐项 | 新增8组真实Run边界 | 其余卡牌组合、全部公开交互的逐项验收 |
| 5 同候选两幕结算 | 无 | 同候选自然两幕、平台日志/截图/结算 |
| 6 开放条件/美术道具 | 正式白名单仍拒绝雷电 | 完整角色入口、美术、牌/道具真实交互验收与开放决定 |

候选GIL写入/读回、官方导入、新ready、PC设备、手机设备、同候选自然两幕均 `NOT_RUN`。合入前仍需主控安排可追溯独立复审及组合CI；本轮未提交Git或开启集成流程。

## 全部交付路径

- `backlog/tasks/task-85 - 验收下一版本雷电将军两幕玩法.md`（仅Backlog CLI更新）
- `tests/raiden-v4-verification.test.mjs`
- `tests/lua/support/raiden_v4_public_commands.lua`
- `tests/lua/support/raiden_v4_rollback.lua`
- `docs/backlog-details/TASK-85-OFFLINE-20261103.md`
- `docs/evidence/raiden-v4-verification-20261103/replay.mjs`
- `docs/evidence/raiden-v4-verification-20261103/results-initial.json`
- `docs/evidence/raiden-v4-verification-20261103/results.json`
- `docs/evidence/raiden-v4-verification-20261103/negative-controls.json`
- `docs/evidence/raiden-v4-verification-20261103/development-history.md`
