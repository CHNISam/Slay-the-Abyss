# PR197 Living Wall 独立只读复审

结论：在下述限定范围内未发现新增可报告的 P1/P2。新增 9 组独立真实 Run / Nodes / 原生 UI 事务回归全部通过；这不是完整 M3、全概率池或平台验收结论。

## 固定对象与来源

- 实际执行源：`efd3feb7052d0a8f7b4b8410d8507a7e5584c556`，PR197，base `9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db`。
- 收尾再次读取 PR 时 head 已为 `6457b61f9f600178ad8279839243c82f52b772cd`。独立 GitHub compare 确认仅 `tests/lua/card_pool.lua` 变化；另逐文件重新读取 LivingWall、Nodes、NodeUI、Transform、Capability 五个关键 blob，与 efd3feb 全部相同。因此本次活墙生产行为结论适用于 6457b61，但没有据此认证新 head 的完整 CI。
- 已读最新 develop 的 AGENTS/HANDOFF/SCOPE、现有 TASK-13.1.2 首页和附件、PR body、Living Wall 专项来源/边界文档。附件仍有旧 restricted 范围历史叙述，按最新 SCOPE/任务首页的 25 事件范围解释，不重复报告其阶段边界为 bug。保留有效 owner，未写 Backlog/远端。
- 固定规则核对：`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 `events/exordium/LivingWall.java`，blob `d6f3c805d087cda56681ed0bebe33f7630e267da`，SHA256 `0ceb58080e64863b50b4bb09b36944d215563e6df9e4275274150dff5b63a7cb`。直接读取并独立验 hash，核对三选项锁定、Grow/瓶装组前置、单次事务方向；不认证 PC 二进制。交付中不包含第三方源码。
- `materialization-audit.json` 核 130 个已物化文件的 Git blob；生产源/数据/构建脚本均为固定 head 字节。HANDOFF 明确记录来自 base develop，而非误称 head。

## 新增独立回归

`independent-living-wall.lua`，9 组通过，未照搬现有 72 槽 / 7 原型扫描：

1. Forget / Change / Grow 在锁定选项之前直接携带 UID 均拒绝，值与所有旧表引用不变。
2. 三张同身份牌变换中间 UID，只移除目标、保留左右对象并尾部追加全新 UID；旧卡和旧 misc RNG 对象不变，cardRng/稀有度偏移不受影响；新 UID 重复提交拒绝。
3. 原目标本身为 Anger 时，完整源池先排除同源身份，再以固定零输出向量一次抽得 Cleave；misc 包装计数只增加一次，不重抽。
4. 原生 Change 缺映射连续两次确认均原子拒绝，界面保留同一选牌/锁定 choice；补齐正确内容映射后重试只提交一次，结果继续按钮不再次变换。
5. 13 张同身份不同 UID 牌，第二页选牌后重排永久牌组；确认仍删除原 UID 而非旧位置，保留重排后的其他对象。
6. 原生 Grow 目标在确认前已升级时拒绝；不升级其他牌，不改旧引用；随后重新选择当前合法 UID 可完成。
7. 隐藏面板期间旧确认拒绝；重新打开后同一选中 UID 可正确完成。
8. 节点已锁定 Grow 后重建 UI，直接恢复选择器且不重放选项，永久升级一次。
9. 上一次渲染的 Down/Up/Click 不得消费重绑定或内容恢复后的确认动作；新手势成功一次，重复 Click 拒绝。

另运行既有 `tests/lua/living_wall_ui.lua` 的 4 组作为 fixture/control smoke，全部通过。这 4 组不计入新增覆盖。

## 执行与证据

- `node scripts/build-lua-data.mjs`：通过。
- `node scripts/build-ui.mjs`：通过，仅本地生成测试依赖，未构建/导入关卡。
- `python $LUA54_RUNNER evidence/independent-living-wall.lua`：9 tests, 0 failed；Lua 5.4 native shared library，最终独立执行约 0.075 秒。
- 同 runner 执行 `tests/lua/living_wall_ui.lua`：4 passed。
- 首轮新增指针测试失败为 reviewer fixture 未像真实宿主那样打开默认隐藏的 nodePanel；取证表明 visibleAction 合法拒绝隐藏面板，补 `root:SetVisible(true)` 前置后通过。未改生产源码、未把 fixture 错误报为产品问题。初始测试保存在 `independent-living-wall.first.lua`，最终回归为 `independent-living-wall.lua`。
- `independent-living-wall.log`、`existing-ui-smoke.log`、`source-verification.json`、`successor-diff.json`、`successor-relevant-blobs.json`、`materialization-audit.json` 保存结果/身份。
- 只读查得 efd3feb 的 [Quality 40132311067](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40132311067)：check failure，presentation success。card_pool 第83项后原30秒预算失败为作者已记录问题；本复审未重跑 CI、未启动 full npm/check 或重型扫描、未安装依赖。当前环境无 Backlog CLI，不做生命周期写入。

## 保留边界

Living Wall 尚未进入正常 25 事件概率池，transformContext 由全池 owner 提供；原有 72 槽 27 可用 / 45 原子拒绝、7 原型 capability 修复均不重新报为新增问题。永久移除/获得钩子、完整卡池/遗物组合、Searing Blow 重复升级和 UI 平台门禁仍是已声明未完成边界。新增测试不认证这些内容，也不替代 Fengari 完整 CI 或实机。
