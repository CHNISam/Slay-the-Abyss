# 卡牌旧 Drag 来源污染：本地候选

结论：当前 develop 可复现已取消 card1 的迟到 Drag 借用相同 touchId，改变 card2 的预览（6→9↑）及瞄准位置。候选修复仅限输入归属；合法释放仍按释放坐标结算，缺坐标仍取消。本轮未发现或宣称错误伤害。

## 接续文件

- `candidate.patch`：标准 a/b 路径补丁，仅修改 `src/lua/abyss_battle_ui.lua`，新增 `tests/lua/battle_ui_drag_source.lua`，不包含其他旧源码、任务或文档替换。
- 补丁 SHA256：`a321996743d786872a9d056e01f2d075148d8e273eb00504e000f97e2d1b6584`。
- 生产源码 SHA256：`454e0d1bee3220be71d1ed337703b4e1d5528fe8e6dc57baad6723ec2a9801c1`。
- 新测试 SHA256：`69421894afc0b00d8791c811c9aab9599784c1c90af973f928f8f3168205fe01`。

## 冻结来源与改动

- develop：`9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db`。本地基线390个文件逐 Git blob 匹配，零差异，见 `context/verified-base.json`。
- PR196 首次执行源：`824a5da106525a95e7a0e8cf5c1e8ec0b411123a`；复核当前 head：`df64701a6a618b0a24e7352e04f68acff4ddb984`。两者仅文档/证据及 Boss 奖励测试分拆变化，没有 src/data/构建脚本变化；battle UI 均为 blob `07e76b7c805a505f2ca5f40d3c52ed5c3709a89c`。比较明细见 `context/ref-identity.json`；执行所需61个源模块、生成模块和直接夹具身份见 `context/pr196-executed-source.json`，不把整个共享快照宣称为准确head。
- PR197：`6457b61f9f600178ad8279839243c82f52b772cd`；battle UI 与 develop 同为 blob `3c44a86ac012bdc7bd535f2b808f4275647f74c8`。
- 每张卡的 Drag 显式传入其 input owner；move 在改坐标/预览之前核 owner、当前 held token 对象、touchId 和现有 run/battle/turn/slot/UID 有效性。拖动层保留当前手势续接。release 在最后坐标处理之后消费 held token，避免正常释放不能换目标。
- 保持 PR195 药水保护及 PR193 奖励分组。生产文件只有上述局部hunk；不整文件替换 PR196 在途battle UI。

## 实际验证

- 新增10组：原始生产代码5通过/5失败；候选10通过/0失败。初版9组先红后最小修复，再补当前 held token 故障注入组；所有原始红例保存。
- 18个相关 Native Lua 文件最终共228组通过，包含53组 battle UI、10组新测试、输入归属、拖牌/卡面、点击备用及药水/动作兼容。
- 首次直接运行 battle_ui.lua 因缺官方 runner 注入的 ABYSS_TEST_LAYOUT 失败，精确基线同样失败；按官方脚本用真实 battleLayout 注入后53组通过，前两次错误日志未删。
- 5项有限 mutation 全被拒绝：去来源owner、去held token、去cardReady、去touch核验、提前消费release token。见 `evidence/mutation-results.json`。
- PR196 运行源上的同一10组：原版5通过/5失败，候选10通过/0失败。其后head变化不涉及运行源；没有重跑新的 Boss 奖励分拆测试。
- 对 develop 源及当前 PR196 等同源，实际 `git apply --check` 均退出0。另在独立 PR196 源副本实际 `git apply`，输出源码与已测试PR196候选逐字节一致，新测试亦一致。见 `evidence/apply-check.log`。

## 边界与交接

只有本地代码和回归候选，未提交/推送/合并，未修改Backlog或认领任务。交给 PR196 原集成者决定接入，应用前重查head及写入冲突，再执行其当前SHA正式门禁。

本轮使用 Native liblua5.4 和真实生成控件树事件桩，不是 Fengari、完整 npm check、平台编译/导入、鼠标或手机实机验收。没有安装依赖或重试被拒的完整检查路径。

host事件只有 touchId/坐标，不能识别“同一卡控件、同touchId、重新Down后的旧包”与新的合法包。这里的 generation 是当前 held token 与 gesture 对象的严格同一性；故障注入仅认证此内部不变量，不冒充真实宿主提供nonce。已证明拒绝的是旧其他卡来源，不能承诺所有同源延迟包均可识别。
