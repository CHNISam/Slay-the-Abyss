# M7 CardUpgrade 独立交付：真实 planning floor

## 范围与保留边界

主线基线 `d8a57cae2a867200ca8e588abc0d368e6cdb3799`；直接实施基线为已独审的 `51f77e3fb21770a6fbb72bae9d602d631e2e7843`，原 tree `f64565ec48d4e841dc3bc4425b1f04fb52a52e58`。原工作树保持不动；本树不含 Actor、Potion、Act3、EndTurn 或其他在途切片，也不借用 #541 尚未合入的预算。

原4个生产路径、architecture、static policy、CardUpgrade行为/VM/helper/raw测试、五owner来源桥与proof、完整333源码archive及原机器/质量证据逐字保留。archive继续标真实 `2ad07111`，另核全部333 Git blob与实际d8基线一致，不改旧oracle、guard、read count。共享CI校准合同与其外层入口允许接入新floor；共享responsibility合成夹具补全现有required根，旧门槛和断言不变。

本轮不重复大型行为VM、raw Lua、工程全库测量或Full。原结果只是按当前相同输入复用，不能冒称新跑：Combat SCC81→80、Session15不变，CC>15 237→236，CC>30仍58/max75。原兼容限制、失败与103个唯一JS/6个原raw文件/新增raw11组证据见[原切片说明](M7-CARD-UPGRADE-OWNERSHIP-20261107.md)。

## 成本与严格当前身份

仅在 `scripts/ci-test-timings.json` 的 `jsPlanning.localLowerBounds` 新增行为文件一项 **28384ms**。全部9个原floor、实测平台表、raw安全/分片表、unknown fallback、initial、metadata、quality shape与预算保持。完整旧timings SHA256 `a5841ddaa53d8bc810f9c16ae342ed2de8cb5479bbcb073562d2c6c921ed1b24`。

[规划收据](../evidence/m7-card-upgrade-planning-floor-20261107.json)保存原始成功和失败日志、精确wall/Node口径及source绑定：

- 最终完整成功21/21：wall `28383.44112300547ms`、Node `28317.242988ms`。floor取所有完整成功wall/Node最大值向上取整。
- 较早20/20成功wall `26404.20264803106ms`、15/16失败wall `21731.639033008832ms`、未执行Node的launcher失败、Searing期望/静态夹具错误、真实Drain失败及pairs修复均保留，不把旧成功说成最终源码重跑。
- raw两次wall `848.2686839997768ms` / `846.6111510060728ms`，对应原9组/最终11组。上取整849ms只保留为本地观测；现机制没有本地raw floor槽，仍取10000ms unknown并exclusive，未伪造Hosted或安全校准。
- 原50日志逐字/hash核验；359个生产、行为/helper和工程输入保持。原334模块5396/5396完整测量、1786受管、14告警继续按原证据复用，不冒充本轮测量。

新timing inverse只接受精确完整LF/CRLF身份，删唯一CardUpgrade项必须恢复整个旧timings摘要，再进入原历史链。无live-owner读取、权限缓存、宽松JSON等价许可或新压缩档。当前validator要求新完整epoch；合法旧epoch不能冒充当前，删除floor实际失败。

新增窄合同逐项拒绝全部旧floor的删除、数值/metadata改动、新floor降低/删改、实测权重、raw权重、fallback、reserve和metadata漂移，检查warm成功后变更再恢复的鲜验证。另6个真实Node子进程分别修改实际timings并运行具名当前门禁：删除/降低新floor、改旧floor、改Hosted权重、改metadata、改raw安全值，均exit1命中当前身份断言，随后原字节恢复。

## 当前全库存与预算

[完整分片计划](../evidence/m7-card-upgrade-delivery-planning-20261107.json)包含所有文件、每片精确JS/raw名单、负载及余量。基线746 JS/1402 Lua，当前748 JS/1403 Lua，唯一增量是CardUpgrade两个JS和一个Lua。17个Windows及13个POSIX各自JS完整一次，Windows raw完整一次；POSIX按原机制不额外跑raw。保留2个raw worker、并发上限12、每片60000ms reserve。

| 来源 | Windows含reserve / 余量 | POSIX含reserve / 余量 |
| --- | ---: | ---: |
| d8基线 | 1711077 / 88923 ms | 1191130 / 8870 ms |
| 当前库存、未加floor | 1712897 / 87103 ms | 1192667 / 7333 ms |
| 当前库存、28384 floor | 1713948 / 86052 ms | 1194082 / 5918 ms |

原Windows1800000ms、POSIX1200000ms预算未改。**POSIX仅余5918ms估算空间**，计划不是Hosted完整作业时长证明，不保证CI不超时，也不声明merge-ready。

## 窄验证与已知问题

- CI校准/Host/Windows shape18项、responsibility17项、CardUpgrade source15项、Windows/POSIX分片与raw worker17项，共67项唯一窄测试；最终结果见[交付验证收据](../evidence/m7-card-upgrade-delivery-validation-20261107.json)。无大型CardUpgrade行为VM或Full重跑。
- 新责任根原先使共享合成Combat夹具真实失败3项；只补 `upgradeIndex`、`upgradeNewIndex`、`upgradePairs`。原逐根/嵌套CC16与missing循环保持，另加owner/Warrior模块/嵌套/缺测负例。未改生产policy。
- 本轮早期CI夹具错误、raw旧9组与最终11组混认、缺测错误消息断言等开发失败日志全部保留；修复后重新检查，未隐藏失败或改原产品断言。
- guidance、verify:backlog与diff-check独立记录。TASK-74.19仅CLI追加备注，不改owner/status/AC。环境恢复后原/tmp CLI丢失，恢复官方npm `backlog.md@1.55.3`到持久工具目录；未声称它等于旧版本。
- **Backlog doctor非零**：CLI1.55.3在d8原始backlog快照和本候选均报5组既有归档重号（25.3、25.4、61、64、69），输出逐字相同。未执行fix、未改归档、未降级绕过；不能报告doctor通过。项目verify:backlog与该新版全归档诊断分别记录。

没有push、PR、评论、Full、Hosted运行、合并、发布、官方导入、runtime-ready或用户设备验证。后续精确HEAD独审及合前/合后Full由主控另行处理。
