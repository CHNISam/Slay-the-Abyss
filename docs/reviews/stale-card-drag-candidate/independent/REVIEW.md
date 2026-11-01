# 旧卡牌 Drag 来源候选：独立评审

结论：在本次限定的本地输入归属范围内，未发现新增 P1/P2 或阻断项。冻结候选修复异卡旧 Drag 污染当前卡预览/准星的问题；正常释放与点选行为保留。该结论是本地候选评审，不是任务认领、PR 合并批准、全量检查或平台验收。

## 固定身份与隔离

- 基线：develop `9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db`。
- 审查源：`src/lua/abyss_battle_ui.lua`。
- 基线源 SHA256：`3a64f0bc7e766f5f2fdab093a84c17982942838e992174b353256e8a8e1b8ea6`。
- 冻结候选源 SHA256：`454e0d1bee3220be71d1ed337703b4e1d5528fe8e6dc57baad6723ec2a9801c1`。
- 独立 probe：`independent-drag-review.lua`，SHA256 `1009378ee86a79c26060e0e5cbe05ed38cf9ddfc4480a2dcea0636a33f59baac`。
- 本目录为独立物化快照，非 Git worktree。独立按基线 Git tree 核验 390 个文件，0 差异，其中 52 个生产 Lua 模块全部匹配。
- 候选与基线这 390 个文件之间只有 battle UI 一份生产源变化。运行结束后再次核验候选源未变，仍与作者冻结文件相同。
- 已读匹配基线的 AGENTS、HANDOFF、SCOPE、TOOLCHAIN、UI_DESIGN。环境没有 backlog CLI；没有实施任何 Backlog 生命周期操作。

## 变更审查

卡牌控件的 Drag 闭包传入自身 input。move 在修改坐标之前要求来源与当前 gesture.input 一致、当前 input.held 是同一 gesture 对象，并通过 cardReady 的 run/battle/turn/slot/UID 校验。捕获层没有单独 card input，仍可服务当前合法拖动。

release 延后清空 held token 到最终 move 之后，这不是可随意删除的排序调整：Up/EndDrag 可能携带此前未收到 Drag 的最终坐标。提前消费 held 会让新增 move 校验拒绝这次合法更新，错误保留上一个目标。

## 独立执行结果

每个快照都用匹配源码重新生成 Lua data、UI、theme。运行器为既有本机 liblua5.4 ctypes runner，没有安装依赖。

| 验证 | 结果 |
| --- | --- |
| 自写 11 组 probe，原基线/整补丁撤回对照 | exit 1，6 过 5 败 |
| 同一 probe，冻结候选 | exit 0，11 过 0 败 |
| 既有 battle_ui_card_play | exit 0，11 过 0 败 |
| 既有 battle_ui_gestures | exit 0，11 过 0 败 |
| 既有 battle_ui_potion_ownership | exit 0，9 过 0 败 |
| 既有 battle_ui_potion_compatibility | exit 0，11 过 0 败 |
| 限定 mutation：将 held 清空提前到最终 move 前 | exit 1，9 过 2 败 |

冻结候选本轮总计 53 组通过（11 独立 + 42 既有）；未将作者自己的测试数字并入。

独立 probe 覆盖：

1. 保存 card1 原 Drag 回调，取消后以相同 touchId 拖 card2；旧 card1 回调不能改 card2 预览、坐标或准星，旧 card1 Up 不能消费 card2。
2. 外来卡控件 Drag 不得让静止的当前卡进入 moving；当前卡自身 Drag 仍可启动。
3. 相同 slot/UID 经显式 redraw 与 presentation-only redraw 后保留当前 held token，正常拖动和捕获层释放仍有效。
4. 相同牌型在固定 slot 换成不同 UID 后，旧 g 不得在 render 清理前先改坐标；清理后新 Down 可正常操作新 UID。
5. 两个明确标为故障注入的 held-token 诊断：置空、换成另一个 table，均不能继续移动旧 g；恢复当前 token 后合法操作正常。
6. 卡控件与捕获层的 Up/EndDrag 四种释放组合均在无最后一次 Drag 时采用最终坐标；重复 Up/EndDrag/Click 不二次扣费。
7. 缺坐标释放仍取消；resize 中断后同槽同 touchId 的新 Down 可重试。
8. C 档卡牌 Down-Up-Click、敌人 Down-Click 与纯 Click 卡牌/出牌区均保留。卡牌 Down-Click 缺 Up 在基线及候选都拒绝，不将其误报为新回归或声称支持。
9. 既有药水 fresh-confirm 语义保留：先前选敌不自动使用药水；旧卡 Drag 不破坏新药水 aim；新敌人 Down-Click 确认只消费一次。

撤修 mutation 的两处红例均是合法释放最终坐标：同 UID 重绘后的 overlay Up，以及 owner Up/EndDrag 路径。证明测试既能抓原问题，也能拒绝会损害正常输入的错误修补。

## 必须保留的边界

- 原缺陷是当前预览/准星被旧异卡 Drag 污染。基线合法 Up 重算目标、缺坐标取消、药水确认与 C 档控制组均通过，不宣称修复了原本不存在的错误伤害或误出牌。
- 宿主事件只有 touchId/坐标，没有 packet nonce 或 generation。旧包若来自同一个控件、同一个 touchId，且新 Down 已开始，无法凭此接口区分旧包与合法新 Drag。候选与本评审不声称解决这一不可辨同源重放。
- held-token 两例是受控状态注入，证明对象身份 guard，不代表实机已经观察到该故障序列。
- 没有重复泛扫，没有运行 full npm check、安装、CI、构建/导入 `.gil`、实机、UI 验收。未修改作者文件、PR196/197 源码、远端或 Backlog，也未使用用户电脑/Codex。

## 取证入口

- `evidence/identity.json`：固定 SHA、来源与候选增量。
- `evidence/base-materialization-audit.json`：390 个文件逐 Git blob 对照。
- `evidence/results.json`：各次命令目标、退出码与摘要。
- `evidence/base-independent-final.log`、`candidate-independent-final.log`：同 probe 红绿。
- `evidence/mutation-early-consume.log`：有限撤修红例。
- `evidence/existing-*.log`：42 组既有保护。
- `evidence/reviewed-production.patch`：独立生成的一份生产补丁，不包含作者测试补丁。

复跑方式：在 `candidate` 目录执行 `python3 ../run-lua.py ../independent-drag-review.lua`；原基线对照改在 `base` 目录。构建日志分别为 `evidence/base-build.log` 与 `candidate-build.log`。
