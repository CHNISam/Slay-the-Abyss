# 离线候选源文审计（TASK-19 工具切片）

`audit-native-candidate.mjs` 只核验导出的完整游戏副本与指定提交的源文/生成内容；**通过仍不是官方导入、试玩、UI 实机或音频验收**。输出始终保留 `officialImport/playtest/audio: NOT_TESTED`，不关闭 TASK-19 的发布关口。

```powershell
node scripts/audit-native-candidate.mjs --source 139de949b173c8343d628ce6ba036097a9ff954e --candidate <完整游戏.gil> --output .artifacts/audit-normal
node scripts/audit-native-candidate.mjs --source cf6969e768a6102a726948742dd327642043c2ab --candidate <BGM候选.gil> --output .artifacts/audit-bgm --bgm
```

必须使用本地 Git 中存在的完整 40 位提交 SHA；短 SHA、HEAD 等标签不接受。输出目录必须是新目录，避免覆盖已有证据。默认审常规完整候选；已启用 BGM 必须显式 `--bgm`。普通源提交可能包含关闭的 BGM 模块，模块比较仍以该提交完整部署清单为准。

候选使用原始参数先解析文件系统真实路径，不先词法折叠 `..`，并要求普通文件；原始写法或真实路径含 `Beyond_Local_Save_Level` 目录组件均拒绝。输出先解析原始路径的最近已有父目录，再创建新后缀，避免符号链接加 `..` 静默重定向证据；若文件系统尚未解析的待创建后缀中仍含 `..`，直接拒绝。真实输出目录若已存在仍拒绝覆盖，报告的 `evidenceDirectory` 与 CLI 的报告路径指向实际证据位置。此路径边界以自建临时文本文件在 Linux 验证，未据此宣称 Windows junction 或真实存档已验证。

依赖现有 Node、Git、tar、Python 和已安装 Miliastra MCP，不新增 npm 依赖。工具路径遵循 `docs/TOOLCHAIN.md`，可用 `MILIASTRA_MCP_ROOT` 指定本地工具目录。只运行可信项目历史中的导出脚本，不从网络下载源码。

命令先读取并保存 `miliastra://workflow` / `miliastra://platform-rules`，服务环境固定 `MILIASTRA_ALLOW_LIVE_WRITE=0`；随后复用本地 MCP 的只读解码函数，不调用写存档、官方导入、键鼠或试玩接口。官方 `Beyond_Local_Save_Level` 路径拒绝作为输入，须先提供导出副本。

核验范围：

- 从指定 SHA 导出独立源码快照，在快照内运行现有 data/UI 导出脚本；按该版本 `candidateScriptFiles` 清单比较全部实际模块，包括额外/缺失模块和文件名。只规范化 UTF-8 BOM 与 CRLF/LF，报告同时保留双方原始 SHA256。
- UI/牌库模板比较名字、类型、子顺序、位置、尺寸、文字、图像、网格和按钮状态。完整根 interface 元数据也须匹配，包括 name、脚本及 hidden/showCursor/blockKeys/blockCursor/isolateNavigation；这些布尔项按原生缺省 false 比较，未知根字段不会被丢弃。只在控件 colour 及文本 colour/background/outlineColour 字段统一颜色大小写，正文、名称、资产名和脚本参数字符串保留原样。其余已测的原生缺省值与浮点精度按对应控件/文本/网格语义规范化；填充隐含的 mask 与编辑器 preview 单独规范化。控件数和最大直接子项从同源生成树计算；界面容器与根壳不混入 `interface.controls` 树口径。
- 结算图必须是非空服务端图，监听该源生成器声明的信号，并启用挂在原生 stage 上；BGM 模式额外核 BGM 图与字段 7/8 两份 `nativeBgmEnabled` boolean true。不手填图 ID，节点数及原始图摘要均留证。
- 数值容差仅限有限 UI 浮点字段：控件的 position/size/scale、rotation/opacity，text 的 fontSize/minFontSize/opacity，grid 的 itemSize/spacing/padding，绝对差不超过 0.0001。根元数据、脚本参数、图像 ID、网格列数及其他未知数值严格比较；同名键藏在不透明脚本/元数据中不会获得容差。图 nodeCount 必须是正的安全整数，缺失、字符串、非整数及非有限值均拒绝，仍不认证编译节点参数语义。
- 保留静态检查全部警告；错误、源文/结构不符或候选复读前后 hash 改变均返回结构化 `issues` 并退出 1。成功退出 0；参数/环境/解码失败同样返回非零。

输出目录包含 `audit.json`、`sourcehash.json`、原始 `scripts/ui/template/inspect/parameters/static-check.json`、workflow/platform-rules、同源快照与生成日志。警告不是自动证明安全；当前 17 条须按实际内容审阅。

普通模式若指定SHA的`candidateScriptFiles`明确声明`nativeBgmEnabled: false`，两份原生字段7/8必须都是正确boolean类型false；不依赖静态检查器间接兜底。旧SHA未声明该变量仍可审计，BGM显式模式继续强制双true。此合同增量先红后绿，8组审计及相关15专项通过，独立9个负探针复核；真实`11b901f`普通候选30模块逐byte同源并通过新合同。

边界：图检查覆盖身份、类型、监听信号和启用挂载，**不认证编译节点参数或完整规则语义**；需要结合独立规则账本、构建证据及实机结果。也不验证渲染后的视觉、动画、触控、性能、音量/循环/无叠播、赛事资格或人工发布。相同代码可存在于多个提交，存档没有可信提交标签，因此这里只证明内容与给定 SHA 相符，不能反推出唯一原始构建提交。

专项验证：`node --test --experimental-test-isolation=none tests/native-candidate-audit.test.mjs`。小 fixture 是 `cf6969e` BGM 候选真实复读响应的裁剪，保留 provenance 和原始结构，覆盖换行/BOM容差、坏/缺失/额外模块、错误 UI、未挂载图、错误信号/参数、静态错误、hash 改变和完整 SHA 校验。CLI 另实际核对普通 `139de94` 与 BGM `cf6969e` 两个候选，并以错误的 `cf6969e` SHA 核 `139de94` 候选，确认静态 0 错误时仍因源文差异退出 1。未运行全量检查或游戏。

## 显式编译并比较完整图载荷

以下独立命令会在新输出目录编译指定 SHA 的图源，补充上面只读命令的参数审计。**上面的默认只读命令不会调用它，也不会暗中编译或写副本。**

```powershell
node scripts/audit-native-graph-payload.mjs --source 139de949b173c8343d628ce6ba036097a9ff954e --candidate <完整游戏.gil> --output .artifacts/graph-audit-normal
node scripts/audit-native-graph-payload.mjs --source cf6969e768a6102a726948742dd327642043c2ab --candidate <BGM候选.gil> --output .artifacts/graph-audit-bgm --bgm
```

复用已安装 MCP 的 `Service.compileTogether` / 单图 `buildProject`、现有 GIA injector 与 genshin-ts `NodeGraph` 解码器。编译源从固定 SHA 的隔离快照生成；图 ID 取候选实际身份，图名和服务端类型必须匹配。单图编译工具会在 `output/compiler` 中创建输入副本与构建文件，多图编译也只在该目录写 TypeScript/GIA/日志。原候选只读，预期注入在内存执行，不调用 apply/导入/游戏接口，`liveWrite=0`，前后输入 SHA256 必须相同。

完整比较两边解码的 NodeGraph，包括 literal、pin 类型与连接、图变量初值、compositePins、affiliations 和节点绑定信息。数组顺序和可选字段是否存在均保留，不补默认值、不改节点编号。只排除编辑器布局坐标：`GraphNode.x/y`、`GraphNode.comments.x/y`、`NodeGraph.comments[].x/y`；注释文字仍比较。原始字节哈希与排除坐标后的语义哈希分别保留。

双方必须先通过原始字节的 decode→encode 完全相等门禁；未知协议字段、丢失信息或不支持的 wire 顺序返回 `GRAPH_SCHEMA_UNSUPPORTED`，不会以静默丢字段获得通过。已实测真实结算/BGM 图可无损往返，重复编译仅坐标变化时语义哈希一致。真实结算图加未知 protobuf 字段的解码结果已进入 fixture，对应导出测试副本也经实际 CLI 以 `GRAPH_SCHEMA_UNSUPPORTED` 退出 1；literal、type、variable、signal binding 四种仅在导出测试副本内的改动，实际 CLI 均以 `GRAPH_PAYLOAD_MISMATCH` 退出 1。

该命令与默认只读审计应一起使用：它不重验模块、UI、静态检查或 stage 挂载。现有 injector 会根据输入的外部信号定义解析绑定 ID，因此本比较**不能证明外部信号定义本身与源一致**；stage/prefab、完整规则行为和实机仍在范围外。输出保持 `officialImport/playtest/audio: NOT_TESTED`。

输出为 `graph-payload-audit.json`、双方完整解码 JSON、固定 SHA 源快照、生成 TS、编译 GIA/日志、编译器与解码文件哈希 `toolchain.json`，以及 workflow/platform-rules 原始响应。专项测试：`node --test --experimental-test-isolation=none tests/native-graph-payload.test.mjs`；fixture 来源和工具版本保存在同目录 provenance。

JSON 解码副本供查阅，不是原始二进制的无损备份（JSON 会合并正负零，特殊浮点也有表示限制）。比较直接使用内存中的解码对象，对正负零/非有限数保留区别；复现以保留的原候选、GIA 与原始载荷哈希为准。
