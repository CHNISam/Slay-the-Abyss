# Golden Idol 独立交付证据

基线 `346be8e0`，独立树 `m3-golden-idol`。本树先交独立旧事件 Fruit 缓存代价 P2 `b479559bd00be51a271db46f07966d13a3a98ae2`，该修复不是 Golden 新增功能。本批没有修改 Backlog、他人树、Combat/Actor、职业牌或药水模块，没有推送、PR、平台或前台操作。

范围是单个真实遗物/事件与普通战斗 GOLD 创建位置：SPECIAL 定义、INTRO 当次取得、强制陷阱三代价、RESULT 保持、重复 Circlet、原生 UI、金币额外部分单独 Java-round 并冻结、同一 owner Moai 献祭。规则与来源见 [GOLDEN_IDOL.md](../rules/GOLDEN_IDOL.md)，23个实际 ZIP 成员的新锁不改旧锁。

先 RED：公开 Nodes 入场 `event_unavailable`，真实 Run 取得 `relic_content_unavailable`。生产实现后固定 Node24、离线依赖、本树 data/UI 构建，逐个新 Lua fixture 都用 `runLua` 检查实际 status0；没有降断言、时限或改原 fixture。

| 本轮专用 Lua | 结果 | 耗时 |
| --- | --- | --- |
| golden_idol_event | 通过；实际 owner/陷阱/永久 UID | 674 ms |
| golden_idol_costs | 通过；三成本/Fairy/Omamori/Fruit/Circlet/未接依赖拒绝 | 1854 ms |
| golden_idol_rollback | 通过；晚失败/throw/缺定义/无效阶段UID生命 | 3507 ms |
| golden_idol_rounding | 通过；独立11组 IEEE32 截断与最小1 | 1202 ms |
| golden_idol_gold | 通过；33源结果/RNG、冻结、排除项、Ecto、Treasure、晚失败 | 1500 ms |
| golden_idol_natural | 通过；seed16 完整池来源选择、单次删除与完整 RNG | 629 ms |
| golden_idol_ui | 通过；原生三代价/卡名/Fruit显示/旧handler和touch拒绝 | 1360 ms |
| golden_idol_channels | 通过；实际取得→真实源战斗/显式领奖→同owner Moai333 | 1128 ms |

原 `combat_gold.lua` 全部13用例通过，11.602秒，原30秒预算未改；包括正常/精英/首领源RNG、全逃跑、晚奖励失败、药水击杀失败及显式历史回放。新旧 source/manifest JS 共22项通过；原库存门禁仍拒绝遗漏映射、虚假自然渠道或伪造平台完成。

data/UI 构建、内容验证和架构登记通过。静态105条历史警告，无新增；15条严格按同 file/原源行内容/column/code/message（含引用行内容）一对一位置迁移，无新豁免。UI 主 render≤10、全部受管函数≤15保留。未跑全工程重型矩阵。

尚未完成：默认25事件全面开放、全部遗物、完整跨幕自然路线及平台/实机验收。伤害遇 `tungsten_rod/lizard_tail`、Injury遇 `darkstone_periapt` 仍明确原子拒绝，未伪造共享效果。金像专用图标暂复用现有金币 glyph 并标 placeholder，M4艺术及设备验收待补。实际取得→战斗→Moai证据包含显式 Act3 边界跳转，绝不记作整局通关。
