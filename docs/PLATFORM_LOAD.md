# 平台负载与正式候选验收

适用《杀戮原塔2》。日常代码可以集成；正式版本必须另过同候选官方验收。CI 成功不代表可以发布。

## 当前实测基线与离线审计

2026-10-30 用户提供官方编辑器截图确认：关卡存档 **8.96MB / 20MB**；服务器存档 **0.01MB / 3MB**；静态计算、静态内存均正常。上传进度图仅作辅助，网络传输量不参与容量结论。本会话没有取得截图原文件、候选 SHA/buildId、客户端版本和测量时间，故只记录用户确认的基线，不能用于本次新候选放行。原截图进入证据库前须隐藏 UID。

优化后官方容量：**UNVERIFIED，尚未重新测量**。不能将 883 字节的源码减少折算成官方 MB。按面板单位算，基线距内部目标 16MB 为 7.04MB，距关卡上限为 11.04MB；这是该旧候选的读数差额，不保证新资产编码后的容量。

从 `d4c4b25594798f9d2f4fc6b66a061532c2b71595` 审计：262 个源码模块中仅旧 `abyss_random` 无生产引用。本轮保留其源码和测试，正式映射排除它；生成运行时模块全部保留。正式构建和独立读回审计现在共用 `candidateScriptFiles`，复用已有旧脚本清理及最终映射清单核对。后续重新引用被排除模块时，依赖门禁失败，须先恢复装配。

| 离线生产输入指标（不是平台存档大小） | 优化前 | 优化后 |
|---|---:|---:|
| 映射模块数 | 268 | 267 |
| 映射 Lua 字节（构建标记另计） | 3,089,998 | 3,089,115 |
| 布局紧凑 JSON 字节 | 1,309,597 | 1,309,597 |
| 模板紧凑 JSON 字节 | 15,761 | 15,761 |
| 布局和模板控件总数（含模板根） | 10,937 | 10,937 |
| 初始隐藏控件（含祖先隐藏） | 10,746 | 10,746 |
| 模板数 / 精绘宿主池数 | 1 / 0 | 1 / 0 |

初始隐藏数含未打开的完整战斗、节点、药水等页面，不能直接当成泄漏或可删控件。布局中战斗 3,282、节点 4,704、药水入口 771 个控件；精绘宿主当前未启用。7,590 个叶图元实例与其他实例配置相同（忽略名称），大部分来自复用外观的按钮状态、卡面和页面，不能因相同就删除实例。当前只有一个牌库模板，没有发现重复模板或相同内容的映射 Lua。正式入口的全部静态及函数内 require 均有模块，不能裁掉未在本次试玩出现的玩法。

没有更改批准画质、合法手牌/敌人数、玩法或负载需求档位。共享绘图数据已有单份 presentation 装配；宿主控件池和图像数据分别计数。后续卡牌、角色、敌人与背景按实际生产构建重新计量，继续复用 [既有增量实验](art/UPLOAD-BUDGET-20261029.md)，未经组合/手机验证不得扩大装配。动态图元去重、改为懒创建或缩小隐藏池会影响层级、交互和生命周期，本轮没有用未验证改造冒充收益。

最新整合基线还包含 [PR350 背景运行时组件](../art/characters/key-visual/traveler-geo/official-landscape-v1/runtime/README.md)：批准背景为13,201图元，但 `asset.json` 的生产注册仍为 pending、enabled 为 false，目录也不在默认映射清单中。本轮保留整份批准资产，不把源文件入库当成已上传。其64条分批创建、207次tick均不证明设备性能；同步释放成本未测。正式接入后必须重新计量同一候选，并覆盖菜单/选角加载、取消、重入、切战斗和释放的手机峰值，不能沿用本表或8.96MB基线批准接入。

2026-10-30 多怪新画候选：五类美术开关默认关闭，`--art-monsters=true` 显式启用源图数据；完整单位按 actor.id 动态创建，无五怪可见性上限。开启绘图的完整单位模板647控件（其中600图形），关闭绘图为35控件；每个Power实例另7控件，按60子控件上限分页。此为离线结构计数，不是官方容量、峰值、帧率或设备验收，见[多怪说明](art/MULTI_MONSTER_DRAWINGS.md)。

## 日常自动门禁

`npm run check:platform-load` 重建数据/UI后输出 `build/platform-load-daily.json`，不连接编辑器、不启动游戏。

- 使用正式构建共用的生产脚本清单，记录各模块真实字节/hash。已有生成模块白名单排除测试 fixture 和共享 build 残留；构建收据另保存实际写入文件及 UI/模板的 `productionManifest`，读回内容/hash及清理后的映射清单仍须一致。
- 依赖 AST 覆盖函数内 require，拒绝未知/动态加载和重新引用排除模块。重复映射内容、重复模板内容/名称、同层重复控件名直接失败。
- 复用既有原生 UI 容量检查（直接子控件 ≤60、文字及容器合法性）；这是客户端 UI 路径的现有适用约束，不把服务端 UI 或局内存档配额套到此处。没有可离线得出的官方负载估算公式，不自造 CPU/内存限额。
- 比较固定 develop 基线的 Lua、布局、模板、控件及隐藏池增长。任一增长超过 10% 预警，报告具体差值，须审查实际收益和后续资产余量；这只是内部趋势信号。更新基线须在 PR 解释原因并保留前后报告，不能为消警覆盖历史。
- 20MB 关卡和 3MB 服务器分别管理，禁止将任何离线输入字节、GIL 文件大小或上传网络量当作官方读数。历史官方读数缺少候选身份，始终不授予新候选 PASS。16MB 是内部关卡预算预警，超过 20MB 或服务器超过 3MB 则拒绝发布。

接入现有 Quality：完整 Windows/POSIX 第一分片执行；影响生产代码的 fast 路径执行；仅惰性文档变化沿用未变更的生产检查。无需新增 CI 工作流、外部服务或逐 PR 试玩。原生列表生命周期 `check:native-ui-contract` 保留销毁/回收负对照；离线检查不能证明平台帧率或资源清理合格。

CI 与 package 的历史回放使用 `tests/helpers/platform-load-wiring.mjs` 只逆转本轮精确新增的步骤和命令，旧哈希、原分片、时限、权限及工程检查保持原样。`tests/platform-load-wiring.test.mjs` 同时验证当前真实接线，拒绝缺失、重复、错位和篡改；不能仅更新历史哈希来接纳新步骤。修改接线时连同现有 CI/工程质量合同一起运行，避免只测新脚本而漏掉历史回放。

## 正式 RC 的官方门禁

先冻结含音频和最终资产的同一正式候选，使用最终 `candidate.json`，不能使用音频装配前的 hash。在该构建源码工作树执行：

```sh
npm run verify:platform-load -- <最终candidate.json> <official-load.json>
```

未提供证据返回 `UNVERIFIED`；不匹配、超限、缺报告、未验收、存在未解决项则 `BLOCKED`，均非零退出。报告写入 `build/platform-load-release.json`，验证异常也覆盖旧报告，不能留下旧 PASS。CLI 重算候选 hash、当前生产 payloadDigest并复验候选专属精绘来源，证据必须匹配 sourceCommit、buildId、candidateSha256、payloadDigest，且候选必须来自干净源码及已有 `--release-candidate` 冻结流程。普通开发 PR 不运行这个官方证据门禁。

证据 JSON 顶层字段如下（完整可用字段合同见 `scripts/platform-load.mjs` 和拒绝测试 `tests/platform-load.test.mjs`）：

- `schemaVersion: 1`、四个候选身份字段、`clientVersion`、`reviewer`、`recordedAt`（带时区的 ISO 时间）。
- `uidRedacted: true`、`loadTierUnchanged: true`。原始私有资料可单独归档；公共证据使用脱敏版本并对该版本计算 hash。
- `levelStorage`、`serverStorage`：分别为 `{source:"official-editor", unit:"MB", limitMB:20或3, valueMB:实际数值, measuredAt, artifacts:[{path,sha256}]}`。16MB预警，不作为官方上传禁令。单位沿用面板，不推断字节换算。
- `checks`：下表全部项，各有 `status:"PASS"`、`measuredAt`、具体 `notes`、`unresolved:[]`、`artifacts:[{path,sha256}]`。没有执行就写 `UNVERIFIED`，不能提前勾 PASS。
- `dynamicDetectionEnabled: true`、`detectorOverheadAcknowledged: true`；`rawDynamicReport:{source:"official-sandbox", artifacts:[{path,sha256}]}`，保存官方原始报告。`screenshots:{artifacts:[{path,sha256}]}` 必须包含可复核 PNG/JPEG 截图。

所有 artifacts 相对证据 JSON 目录，以实际原始文件计算 SHA256，空文件或内容被改拒绝。时间不得早于本候选构建或晚于当前时间。若同一截图/报告支持多个检查，在各项 notes 写清页签、时间和对应场景。hash、文件头和结构检查不能证明报告真实、截图正确或操作成功，仍由具名审查者看原始资料并核对候选身份，独立审查不能省略。

| checks 键 | 必须实际核实 |
|---|---|
| staticGlobal / staticRegions | 全局及全部区域的计算/内存；无未解决超标，留全区域视图和异常详情 |
| clientCompute / clientMemory | 客户端计算/内存异常页、峰值及处置 |
| serverProcessor / serverMemory | 服务器处理器/内存异常页、峰值及处置 |
| combatPeak / complexHand / enemyEffectsConcurrency | 真实高峰战斗、合法复杂手牌、敌人和特效并发，记录场景与峰值时刻 |
| sceneTransitions / repeatedEntryExit | 切换、重复进入退出，观察控件/内存是否持续增长，记录次数、设备和持续时间 |
| officialUpload / launchAndOperate | 官方试玩校验上传、真实启动和可操作；绑定本次启动标记/日志及截图，复用既有 P0-SMOKE 流程 |
| mobilePerformance / mobileInteraction | 必要物理手机性能/触控，记录设备、设置、持续时间与问题，不用 PC 推断手机 |

动态流程：千星沙箱「窗口 → 负载检测」→ 开启负载测试 → 试玩覆盖上表场景 → 正常结束 → 取得自动导入的报告，试玩及查看报告期间不关闭开关。检查四种异常，不只看客户端 FPS。检测工具自身会增加负载，记录开关和工具影响；必要时补同条件无检测对照，不用对照替换官方报告。

官方将静态计算/内存和动态异常描述为推荐值/风险提示；存档超限明确禁止上传。两者分别记录。工程上仍要求超标问题解决才能放行，不能把推荐值谎称为平台禁令，也不能提高负载需求档位掩盖问题。动态客户端指标与设备有关，服务端与配置人数有关，保持现有单人设置并留证据。

最终人工发布还须通过现有 `verify:ui`、P0 冒烟、内容及发布资格/材料检查；**平台负载门禁 PASS 只是必要条件**。当前官方新候选容量、全区域详情、四类动态报告、高峰/切换/重复进出、上传启动和手机证据均未取得，正式发布状态 **UNVERIFIED / 不得放行**。本轮不占用桌面，实际操作需另获本轮时间窗口。

官方依据：[负载计算功能](https://act.mihoyo.com/ys/ugc/tutorial/detail/mho2hirgodxi)。网页直读无正文，本轮复用已安装工具的官方正文归档 `knowledge/official/guide/mho2hirgodxi.md` 核对静态/动态流程、推荐值与禁止上传的差别；数值 20MB / 3MB 来自用户本轮官方截图确认，不冒称正文写明字节口径。
