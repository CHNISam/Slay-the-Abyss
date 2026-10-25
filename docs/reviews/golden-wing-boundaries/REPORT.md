# Golden Wing 有限独立规则复核

## 结论

未发现本范围内真实生产缺陷。基线 `develop@3ed8bf4b88a950c4736ec2d68e83f141d415c4db` 的 16 个新增规则边界用例全部通过；8 个局部故意破坏均被测试实际捕获；既有 unknown_events 13 组、empty_permanent_deck 8 组全部通过。候选只新增一份独立测试，不改生产逻辑、数值、文案、任务元数据或任何远端状态。

## 任务身份及执行边界

- 已读固定 develop 的 AGENTS、HANDOFF、SCOPE、MILESTONES 及 Backlog TASK-13.1.2 首页/开发附件；当前主关口 M3，M0–M2 已完成。
- TASK-13.1.2 当前是 `In Progress`，实际首页负责人 `@Codex`，不是 Done。这里只做其既有执行器的独立复核，不正式认领、拆任务、改负责人或勾 AC。开发附件旧受限池叙述与首页最新 25 事件决定不同，以最新首页/SCOPE为范围依据。
- Golden Wing 在当前 restricted-seven 中已实现，既有 unknown_events 和 empty_permanent_deck 已测正常金币/献血/末张移除。本次不是新增事件，补的是单击门槛矩阵、资格快照和死亡/重复输入交叉边界。
- 开始时开放 PR 仅 #196，75 卡实现由原作者持有；本候选不修改该 PR 任何文件，不重做 FlameBarrier 或 PR198/199。
- `backlog instructions overview` 实际返回 `backlog: command not found`。未安装、未冒认领、未手改 Backlog。
- 实际执行者是 dot 的 native 云端审查任务，Linux 上 Python ctypes 调用已存在的 `liblua5.4.so.0.0.0`。不是用户电脑、用户 Codex、Windows、自托管 runner、Fengari、千星客户端或原作 PC。

## 新增覆盖

1. Strike 基础6/升级9、Bash基础8/升级10、Cleave基础8/升级11精确门槛；AOE基础伤害符合时可用。
2. Twin Strike 基础5×2及升级7×2均不因合计伤害达标；Body Slam以及仅减费用升级不伪造固定基础伤害。
3. Vajra 不将 Strike+ 的基础9变成事件门槛10。
4. 资格由入场时固定；后续请求不得偷改为重新读当前牌组。此例明确直接变更测试夹具，不冒充自然游玩路线。
5. 1、6、7 HP 献血均终止为败局，不能再净化/拿金/重付/离开；永久UID、金币与四类随机流均保持未额外消费。
6. 8 HP 献血保留1 HP并进入净化阶段；变更选择、重复献血和无效UID逐项原子拒绝；正确UID只能删除一次，不能再次扣血。

全部通过真实 `Run.new`、`Nodes.enter`、`Nodes.view`、`Nodes.chooseEvent` 与 `Nodes.purgeWing` 执行；只有节点类型和永久牌组按明确测试输入设置。地图只生成一次后复制，避免重复全图构建。未运行全量重型性质扫描。

## 固定来源及限制

来源均是 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f` 的已知第三方反编译镜像，不是官方开源或经目标 JAR 认证的原作构建。完整URL和Git blob在 `context/source-metadata.json`。

- GoldenWing.java `4bebe490cacf288ad25bd4042f48575cfb3b9bd2`：构造时捕获资格，7伤害，50–80金币；金币使用一次misc抽样。
- CardHelper.java `f1528bfd5c1bf1fc1d5dc04a8718764dc59d449f`：ATTACK类型且baseDamage >= 10，不累加多段。
- 五张原卡构造/升级文件均已重新读取并保存字节身份；测试预期为固定独立表，不从待测谓词生成。
- 死亡断言检验本项目既有终局资源/导航契约，不外推完整原作画面、死亡动画或所有永久卡钩子。

Runtime中67份既有源/数据/测试均逐份Git blob匹配固定develop，见 `context/verified-runtime.json`。JSON通过仓库原有 `node scripts/build-lua-data.mjs` 验证并生成Lua数据，无npm安装。候选测试位于 runtime 外，生产源保持原样。

## 测试证据

- `evidence/results.json` 记录12次有限执行的退出码、耗时和末尾结果。
- `golden-wing-baseline.log` 与 `golden-wing-final.log`：16/16，0失败。
- 8个负控分别破坏 >=10、累加多击、忽略升级、重算资格、死亡允许回图、死人继续净化、允许换选项、净化重复扣血，全部以真实断言失败退出1；不是生产失败或修复前红例。
- `existing-unknown-events.log`：13/13；`existing-empty-permanent-deck.log`：8/8。
- 初次运行因父级日志目录未建而在shell重定向阶段失败，Lua未执行；已保留 `harness-initial-error.log`，创建正确日志目录后重新实跑。不把该错误当作玩法负例。
- 另一次保存来源的合并命令因参数过长未创建进程；改为每份小文件分别写入并核hash，未改数据。

## 交付与剩余

- `candidate/tests/lua/golden_wing_boundaries.lua`：唯一仓库候选变更。
- `candidate.patch`：只新增上述测试，可由root在确认为未重复时纳入。
- `REPRODUCE.md`：本环境重现命令。

无生产修复建议，无确认P1/P2。未做完整 `npm run check`、Fengari预算、Windows CI、平台编译/写副本/官方导入/实机UI或自然渠道事件获取。TASK-13.1.2完整25事件、M3及平台验收仍未完成，不能因这些有限测试关闭。
