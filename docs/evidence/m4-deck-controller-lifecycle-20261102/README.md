# TASK-4.21：牌库 Grid 的 Controller 注册释放

## 结论与范围

从 `develop 6354f6328fd6b2b7c53a758dd9e470948d21efc1` 的独立分支修复一个非设计生命周期缺陷：DeckUI 原先删除已销毁 Grid item 的自身 binding，却没有释放 Controller 的 `records/byControl` 强引用。`close()` 先清理、再 `RefreshItems(0)`，所以仅在原清理分支加解绑仍不足以立即释放本轮销毁对象。

生产改动仅 `src/lua/abyss_deck_ui.lua`：

- binding 保存原 hit；死亡后不再调用 `GetChild`，直接复用现有 `Controller.unbind(..., true)`。
- 每次主动刷新完成后回收死亡记录；隐藏或详情状态也在 update 清理外部原生销毁。
- 仍存活的复用 item 不解绑、不重复安装监听；不改 Controller、布局、排序、选牌、滚动或动画规则。
- 现有 unbind 同时清理索引、记录、记忆和指向旧控件的导航缓存；其他控件的 record 身份保留。

本轮已在 [PR465 评论](https://github.com/CHNISam/Slay-the-Abyss/pull/465#issuecomment-6570962476) 认领，与图鉴数据层及地图实验不重叠。仅本地提交交独审，不推送、开 PR 或合并。

## 相同真实模块/共享原生夹具的前后计数

`measure.lua` 两次均使用真实 DeckUI、Controller、Combat、CardDisplay、生成数据/布局，以及现有 `game_ui_fixture` 的只读 alive / 递归销毁 / 死亡 GetChild 拒绝合同。仅 DeckUI 源码在固定基线与当前工作树之间切换。12 张牌，非手柄模式。

| 关闭次数 | 基线 records / dead | 修复 records / dead |
| --- | --- | --- |
| 1 | 27 / 13 | 14 / 0 |
| 10 | 144 / 130 | 14 / 0 |
| 20 | 274 / 260 | 14 / 0 |

随后 300 次非手柄 `sync` 的 eligible 扫描量 **82,200 → 4,200**，等于固定14条控件记录的基线。原始输出见 `measurement-baseline.txt`、`measurement-current.txt`。这是离线注册/扫描数量，不是手机 FPS、GPU 成本、加载耗时或玩家卡顿根因。

首轮筛查的桩化绘制探针另存 `diagnostic-baseline.cjs`、`diagnostic-baseline.txt`、`diagnostic-metadata.txt`：它读取当时的 origin/develop 并断言缺陷存在，不是修复验收；上述真实共享夹具已独立得到相同计数。

## 回归与门禁

- **先红后绿**：新增回归在基线实际关闭1次报 `DECK_CONTROLLER_RETENTION: expected 14 records, got 27`（`baseline-red.txt`）。最早的 `fixture-setup-error.txt` 仅为查找嵌套模板的夹具构造错误，不计作产品 RED；修正后才获得真实基线失败。`first-green-attempt.txt` 是补强前6组通过，最终 `lifecycle-green.txt` 为7组。
- 新 `tests/lua/deck_controller_lifecycle.lua`：20次开关、记录/索引一致、记忆/导航引用释放、其他记录身份、controller分页/过滤/排序/空集、设备切换、重开、回收销毁、延迟fill/过时回调、存活复用10轮、详情/隐藏状态销毁、1-based强制选牌及旧tap/Confirm/Cancel、真实Host完整run/RNG对象图不变。
- `npm run check:native-ui-contract`：6项通过。既有死亡guard负控保留同一断言，仅适配多行分支的定位锚点；新增撤销 Controller.unbind 的负控必须命中上述27≠14断言（`native-contract.txt`）。
- 相邻7个原 Lua 入口全部通过：`grid_lifecycle_contract`、`deck_item_lifecycle`、`deck_scroll_detail`、`deck_pile_view`、`deck_browse_filters`、`controller`、`controller_current`（`adjacent-lua.txt`）。
- `node scripts/check-engineering.mjs`：质量采集5021/5021、架构318模块/1838边、固定Luacheck无新增诊断；5021是测量覆盖而非测试个数（`engineering.txt`）。
- `npm run check:test-strength` 四关键变异均由真实断言杀死；`npm run check:syntax`、牌库布局6项、`npm run verify:backlog`、`git diff --check` 通过。相关原始日志同目录。
- `test:related --plan` 正确要求完整检查（Backlog为未建模输入），没有启动全量或把定向通过冒充完整CI。独审与精确SHA完整托管CI由集成阶段另验。

环境：Linux云隔离副本，Node v24.22.1、Fengari 0.1.0；复用既有锁定依赖，Luacheck 1.2.0 下载并校验固定SHA256（`luacheck-setup.txt`）。未使用用户Codex、桌面、GUI、官方客户端或模拟器。

## 复现

仓库根运行 `npm run build:data && npm run build:ui`，然后：

```sh
node scripts/test-lua.mjs tests/lua/deck_controller_lifecycle.lua
npm run check:native-ui-contract
node scripts/test-lua.mjs docs/evidence/m4-deck-controller-lifecycle-20261102/measure.lua
```

基线测量不修改生产文件：

```sh
git show 6354f6328fd6b2b7c53a758dd9e470948d21efc1:src/lua/abyss_deck_ui.lua > build/deck-retention-baseline-source.lua
printf "ABYSS_DECK_BASELINE_PATH='build/deck-retention-baseline-source.lua'\ndofile('docs/evidence/m4-deck-controller-lifecycle-20261102/measure.lua')\n" > build/deck-retention-baseline.lua
node scripts/test-lua.mjs build/deck-retention-baseline.lua
```

已验证生产源 SHA256：DeckUI `e652f6c95c74a34072da49f6019e2915aa9c81b97d54300fca2d8a2fe997e908`；未改的 Controller `bfa156d81cbb4be11b5cdf6f5568051c46e2eacd724fa01b2d827736e6ddf482`。

任务仅以 Backlog CLI 追加计划、笔记和证据引用；保持 In Progress、Furinya 与未勾 AC3。没有 GIL/导入/ready/实体手机证据，不宣称手机性能已修好。
