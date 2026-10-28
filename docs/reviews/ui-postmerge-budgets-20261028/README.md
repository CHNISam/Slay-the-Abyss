# PR313 合后原预算回归收尾

基线为实际 squash `cec690c1701af121e370facde5c1ca2ad9beb99e`。其 tree
`402909058fb8eaad74fe3e909c25158b195bfbf9` 与 PR313 绿灯 head
`9b60ff829b8fd3c2c623782870a79bdde4c0a413` 相同。

## 失败证据与定位

| 原 raw Lua 入口 | [PR绿灯 Quality 40755016999](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40755016999) | [实际合后 Quality 40759203898](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40759203898) |
| --- | ---: | ---: |
| potion_targeting.lua | 28,790ms | 30,076ms / ETIMEDOUT |
| game_ui_exit.lua | 29,064ms | 30,063ms / ETIMEDOUT |
| feedback_continuous_cards.lua | 28,568ms | 30,128ms / ETIMEDOUT |

三项失败均为原 30,000ms 进程时限，没有观察到逻辑断言失败；其余 fixture 继续执行。
这些同 tree 数据证明单文件预算余量脆弱，不证明某一唯一环境根因。
三项既有权重分别为 20,546 / 20,187 / 20,074ms，均超过
`scripts/lua-workers.mjs` 的 10,000ms 独占阈值。原作业日志也符合独占顺序，
故不把失败归因于误入双 worker 池，不通过改权重或盲重跑掩盖。

## 最小改动

复用仓库 `game_ui_class_choices` 的注册范围分片模式：

- potion_targeting：原第 1–4 组 / 原第 5 组（内含全部 9 个生命周期条件）。
- game_ui_exit：原第 1–5 组 / 原第 6–15 组。
- feedback_continuous_cards：原第 1–4 组 / 原第 5–9 组。

只在各文件注册器外加选择、计数和原始序号 marker；新增第二片为一行 `loadfile` 调用。
没有修改任何原 case 体、setup、seed、断言、循环上限或语句次序。
各 case 在自己的函数内创建新 host/combat/反馈状态；片间没有承接前一 case 结果。
完整原源码 SHA256 与 Git blob、唯一可逆注册编辑及分片范围保存在
`tests/fixtures/ui-regression-partitions.json`；Node 合同严格重建并核原字节，
验证真实 case 体/范围漂移会被拒绝，并固定注册器前后文的独立 SHA256；
双改注册器与 manifest 使其只计数不执行的负控先红后绿，不能绕过原文逆向。
raw 与 Windows 8 / POSIX 4 的 Node 合同均唯一发现。

`scripts/test-lua.mjs` SHA256 仍为
`7866bfbb9888417087a669dd20f524de32ccb1efe1d035a283fc1b148d26ed33`，
原 30 秒时限、CI/worker 策略、调度权重、生产源码、golden 均未改。
新增片沿用未知 fixture 的 10 秒保守权重，因此同样独占执行。

## 本轮真实短测

[完整数值与序号](local-results.json)。六片串行调用原 `runLua`，没有传入更长 timeout：

| 入口 | 原 case 序号 | 本轮云隔离目录实测 |
| --- | --- | ---: |
| potion_targeting.lua | 1–4 | 12,013ms |
| potion_targeting_slice_2.lua | 5 | 13,702ms |
| game_ui_exit.lua | 1–5 | 15,315ms |
| game_ui_exit_slice_2.lua | 6–15 | 11,027ms |
| feedback_continuous_cards.lua | 1–4 | 10,536ms |
| feedback_continuous_cards_slice_2.lua | 5–9 | 13,769ms |

六片 status 0；每片严格验证实际 CASE marker 与预期范围，合计原 29 组各执行一次，
无 `FAIL` / `not ok`。运行期间另有短静态检查，不把本机数值冒充托管 Windows 余量证明。
源码/发现合同先红（缺少分片）后绿；本轮新增 5 项与已有 class choices 2 项合计 7/7。
`npm run check:syntax` 与 `git diff --check` 通过；无第三次本地全量重跑。

## 仍须完成的关口

本次新精确 head 的完整托管 Quality、独立审查和 schemaVersion 2
`npm run verify:delivery` 预审尚待采证；必须在合并前保存有效 preflight。
不能为已经关闭的 PR313 补造 open-PR 收据，也不声明其原 native `merged_passed`。
官方导入、ready、PC/实体手机 UI 与性能验收仍未执行，TASK-4 负责人/状态/AC/Done 不改。
