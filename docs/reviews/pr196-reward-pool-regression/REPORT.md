# PR196 首战卡牌奖励回归候选

## 可接续结果

只修改 `tests/lua/card_pool_rewards.lua`。补丁 `candidate.patch` 可以直接应用到 PR196 head `088a6ab6d2fe47dd3bdb4a74bd4e3d01e69e0224`；最后远端核对为 2026-10-25 02:35:25 UTC，head 未变。未改生产规则、数值、旧 30 卡 oracle、Backlog 或任何远端状态。

## 根因与证据

1. 原测试在真实 starter 胜利后失败于第 33 行 `incomplete reward: true_grit`。它把历史 `oracle.blocked` 的七张牌当作未实现；同源 card_pool 主文件已把这七张明确改成可玩/可升级。
2. `true_grit` 当前定义是 1 费、7 格挡和随机消耗；升级为 9 格挡和 UID 选择消耗。实际 `abyss_card_actions` 已实现两个操作。原文件 `warrior75.lua` 的 156 组及 `warrior75_edges.lua` 的 49 组执行通过，含原始/升级 True Grit、真实消耗和选择/触发交互，不以数据存在或 Capability 返回值代替行为证明。
3. 原 27 个奖励目标还有第二个错误：含 4 张稀有牌。新源规则首次普通 A0 奖励从 +5 偏移开始，每张 common 最多减 1；第三槽前最低 +3，不可能满足 rare 的 `<3`。这是作用域修正，不是修改稀有度概率。
4. 修复使用明确写出的 56 个独立 ID：20 common +36 uncommon，逐项与既有固定来源 `data/reference/sts1-card-pools/pools.json:redReward`（source commit `319009d5df0a82d9fb0f23cc22322286c6a87ec0`）核对，未从生产 `sourcePools`、Capability 或实际抽样输出反推预期。独立列表审计在 `evidence/independent-set-audit.json`。

## 保留与增强

- 完整执行 1..128 全部 seed，没有提前结束、预筛种子或缩减样本。
- 真实原数据 starter 战胜 `cultist_solo`，公共领奖命令、独立奖励收尾、公共下一战构造全部保留。
- 观察到 128 次真实首战胜利、384 个奖励槽、56 个唯一合法奖励、56 次领取，以及 184 次开战（128 首战 +56 下一战）。追踪脚本只透传原调用，不替换结果。
- 每个奖励都校验独立合法集合、实际 Capability 和独立稀有度；已领取过的后续奖励仍受校验。
- 增加永久 UID 分配/递增/下一战不变，下一战各实例 UID 唯一、奖励恰有一次且未升级的断言。
- 旧 `support/card_pool_oracle.lua` 完全未改，七牌名单没有清空。稀有牌完整行为/获取不是该首次普通战斗测试的覆盖宣称。

## 最新原生 Lua 5.4 执行结果

- 原始 `card_pool_rewards.lua`：exit 1，预期的 `incomplete reward: true_grit`。
- 候选 `card_pool_rewards.lua`：exit 0，约 1.02 秒。
- `card_pool.lua`：93 组，exit 0。
- `warrior75_acquisition.lua`：7 组，exit 0。
- 诊断时 `warrior75.lua`：156 组，exit 0；`warrior75_edges.lua`：49 组，exit 0。没有在最终循环重复泛扫。
- 覆盖透传审计：exit 0，断言 runs=128、starts=184、claims=56、rewardCalls=128、rewardSlots=384、unique=56。
- `git apply --check`：exit 0。
- 207 个输入逐个 Git blob 匹配固定 head；基线与候选的 12 个生成文件逐字节相同。唯一修改为奖励测试文件。

## 四个真实负控

1. 奖励准备生产路径强制塞入未知 `future_reward`：exit 1，`unexpected first-battle reward: future_reward`。
2. 同路径误放真实稀有牌 `demon_form`：exit 1，`unexpected first-battle reward: demon_form`。
3. 保留合法 `true_grit` ID，把其运行数据效果换成未实现操作：exit 1，`unimplemented reward: true_grit`。
4. 从实际 common 输入池移除合法 `true_grit`：exit 1，末尾 `unseen playable rewards: 2 ~= 0`。池长变化还改变了该128种子内另一牌的采样，故不错误要求缺失恰为1；根本断言仍是所有56个必须出现。首次验证脚本把具体错误写成1时自身报错，原记录保存在 `evidence/execution-results.initial.json`；只修验证脚本为检查既有覆盖失败前缀，不改候选/生产来压绿。

## 工具与边界

只使用云 native 隔离副本、已有 Lua5.4 ctypes runner、只读 GitHub 文件与 PR 元数据、无依赖安装。不运行全 npm/check，不触碰用户 Codex、用户电脑、平台/实机、任务、分支或 PR。Backlog CLI 不存在，已明确记录，未绕过写任务。原生结果不是 Windows/Fengari、当前 SHA 完整 CI 或平台验收；最终集成门禁仍由 root/原作者执行。

## 文件

- `candidate.patch`：单文件最小可接续补丁。
- `candidate/tests/lua/card_pool_rewards.lua`：完整候选文件。
- `candidate-manifest.json`：基线/候选 Git blob 和 SHA256。
- `verify.py`：红绿、四负控、独立目录核对和覆盖审计，可复跑。
- `evidence/execution-results.json`：最后一轮逐命令退出码、时间及预期。
- `evidence/*.stdout.log`、`*.stderr.log`：完整输出。
