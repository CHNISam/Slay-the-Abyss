# 战斗速度正式入口独立复核

审核对象为主 session 新接入的菜单速度入口，基线 `2425ad622eed31ad6a965b90086a6838a1db96f4`。本切片不写共享 GameUI/BattleUI 或规则模块；发现的 GameUI 修复由其唯一写入负责人处理。

## 实际正式入口

`tests/lua/game_ui_battle_speed.lua` 使用正式生成布局、原角色选择面板及真实 Host：标题速度按钮 → 启程 → 旅行者 → 生成地图的合法第一层节点 → 原始起手牌 Strike → 敌人控件。

没有替换卡组、战斗、地图、生命或随机模块。固定 seed 1 只作可重复对照，不作解锁凭证。普通和快速入口分别测得 DamageAction gate 为 0.2 和 0.1 秒，busy 时 setter 和隐藏的菜单回调均拒绝改变模式。两次完整 Run/Map 逐字段递归相等，仅明确排除运行计时 `elapsedSeconds`；包括卡组、永久 UID、战斗状态和全部 RNG 字段。3 组通过。

## 发现并验证的接线缺陷

新增 `game_ui_battle_speed_gestures.lua` 13 组，旧基线实际 8 通过 / 5 失败：

- 退出、更新说明和选角模态已拦截按钮回调，但公共 `GameUI:setFastMode` 仍可穿过三种模态修改设置。
- 失败和胜利结果页继续显示标题页专用速度按钮。其主题矩形 `[280,-222,220,52]` 与结算按钮 `[120,-178,220,60]` 相交 60×12，且速度回调在结果页不可用。

共享文件负责人在独立 Neow 入口树修复 setter 的 menu/模态/settlement guard，以及 `speed:SetVisible(self.mode=='menu')`。本复核仅提取这两个精确改动到临时 overlay，不引入该树的 Neow 改动或依赖；13/13 实际通过，随后 `finally` 完整恢复本树基线源文件。此测试提交须与共享负责人两处生产修复一起集成，不能单独把旧基线称为通过。

其余覆盖包括 click-only、孤立触点、一次授权只切换一次、外来触点、拖动取消、resize、跨模态过期手势、关闭后新手势、disabled，以及公共 setter 的非法输入。结果页测试明确设置终态以隔离 renderer，不冒充自然通关。

## 旧夹具迁移与回归

正式 Host 现在在每个 `perform` 前从 `battleUI.fastMode` 同步到 Feedback。原 `feedback_continuous_cards` 在进入战斗后只设置低层 adapter，故整合后被正常的上层设置覆盖，原 9 组中 5 组实际失败。保留全部组和原时长、状态、事件及冻结断言，改为在 fixture 标题页使用 `GameUI:setFastMode` 后启动；低层 adapter 的“当前批次冻结、下一批次生效”改由独立的真实 Feedback/native-control adapter 验证，不再混用 Host 的授权策略。

原 `feedback_polish` 17 组、`feedback_start_recovery` 5 组、`card_feedback` 10 组和 `game_ui_result_gestures` 20 组实际通过。所有调用保留原 runner、断言和 30 秒预算。迁移后的 9 组首次与另一个 presentation runner 并行执行时在第 8 组达到 30 秒，保留该失败；不以它宣称通过，也未抬高超时。另一 runner 结束后仅串行复跑这份仍未解决的夹具，实际 9/9 通过，用时 16.565 秒；不据单次耗时推断所有 CI 宿主性能。

两个新 Lua 文件由现有完整 Lua discovery 自动发现，无额外调度框架或只覆盖新测试的门禁。没有运行全套 check、键鼠输入、官方导入、声音试听或 UI 实机验收；本记录仅证明相应离线入口与控件回归。

## 历史上游锁与实际 blob 的事实

共享只读参考 HEAD 为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，工作树干净。下列磁盘文件与 `git show HEAD:path` 字节完全相同，均为 LF；本次没有替换既有 source lock，也不推断不一致的来源。

| 文件 | 实际 Git blob | 实际文件 SHA256 |
|---|---|---|
| `dungeons/AbstractDungeon.java` | `9059f4da5c8002e9645bf38f200e5527d1212ac0` | `8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26` |
| `rooms/TreasureRoomBoss.java` | `231d74a575630a1891446610fe5e44b35f5dab16` | `8606510d322714aed59892757891a972da253869c101117665669432a7c5b309` |

`tests/fixtures/cross-act-source-lock.json` 对应历史值分别为 `be88e86db01ce46da3f2762daa0767cbca5224af67fcb77c56622115e21a1a4f`、`4b9e51f575e2ec99612f74e8fe06680ece0454db87ad3ccec81080388930a54f`。这两项当前不能以历史字符串声称匹配该固定 commit 的原始文件；本切片只记录事实，不改 hash 制造通过。
