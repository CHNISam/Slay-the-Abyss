# TASK-38 附件｜手机横屏左右露底：同平台对照调研与复测手册（2026-10-30）

> **性质：研究资料／待实机复测，不是新一轮修复或已通过验收。** 当前用户尚未测试最新源码的实体手机效果。承接现有 **TASK-38 AC#8** 与 TASK-4；不新增任务、不改状态／负责人／优先级／里程碑、不勾任何 AC。研究基准：`develop@9293405dfa07be95c632ac1a15cc4ebc2fb3034b`。公开比赛当前范围以 `docs/SCOPE.md` 为准，只有岩系旅行者第一、二幕。

## 1. 先给未来接手者的结论

- **旧问题确实存在过**：用户手机横屏游玩时，画面左右露出原神蓝天／草地，像卡牌游戏被限制在中间。历史记录为截图 2556×1179、中间背景约 2268px、左右各约 144px；这组历史估值见 `docs/backlog-details/TASK-38.md`，**不是新版本的实测量值**。2026-10-29 的手机反馈 `IMG_1170.jpeg` 亦明确记录蓝天／草地露底；黑色胶囊／橙点属手机系统区域，不能当成需消除的游戏 UI 控件。详见 `docs/backlog-details/MOBILE-QA-20261029.md`。
- **已有确定的代码缺陷及修复**：[PR #207](https://github.com/CHNISam/Slay-the-Abyss/pull/207) 于 2026-10-25 合入 `develop`（合并提交 `c1cb78e8fcbeead0c8439477c39b75f9f4429e8f`）：背景从固定逻辑画布尺寸改为全范围锚点与零尺寸增量；`stage` 仍按 1280×720 等比缩放。该 PR 的[完整 CI](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40175278872) 通过；不代表实体手机验收。原始分层收据见 `docs/evidence/mobile-fullbleed-20261025.json`。
- **本轮没有新的真机结果**，所以不能回答“最新候选是否仍有黑边”。优先让用户试玩最新同一候选；若无露底则保留本资料作归档，不为了预防性修复增加复杂度。
- **对照路线已找到**：同平台 `Pairs` 翻牌游戏（MIT）、`genshin-ugc-webui`（MIT）与 `MiliUI`（**并非开源**，有特别使用条款）均有可比较的屏幕／背景实现。优先比较实现与实机结果，而不是直接认定“平台必然无法全屏”；同时也不能把外部 PC／模拟器成功当作用户手机同候选成功。
- **不要混淆三个概念**：① 底层原神场景露出（缺陷）；② 16:9 主要内容在超宽手机居中，旁边由自有背景覆盖（可以是设计选择）；③ 刘海、系统手势区域／平台不可绘制区域（需实测辨别）。不得仅通过非等比拉伸所有卡牌来“解决”问题。

## 2. 本项目代码路径及当前结构

| 对象／位置 | 已读到的事实 | 排查意义 |
| --- | --- | --- |
| [`scripts/viewport-layout.mjs`](../../scripts/viewport-layout.mjs) | 正式 `withViewport` 生成顶层 `canvasBackdrop`，锚点 `min=[0,0]`／`max=[1,1]`，`size=[0,0]`；下层 `stage` 为 `theme.canvas.base` | 正式背景本应随**直接父级**拉伸 |
| [`src/lua/abyss_viewport.lua`](../../src/lua/abyss_viewport.lua) | `stage:SetLocalScale(min(width/1280,height/720), …)`；不再对背景调用 `SetSizeDelta(width,height)` | 正式主要内容保比例，不代表背景也仅 16:9 |
| [`src/lua/abyss_ui.lua`](../../src/lua/abyss_ui.lua) | `game.GetUICanvasSize()` 启动读取，画布改变后重新 `Viewport.apply`、`view:resize` | 需记录**实际日志读数**，不能拿物理截图尺寸冒充 UI 单位 |
| [`scripts/build-ui.mjs`](../../scripts/build-ui.mjs) | `game-ui.json = withViewport(gameLayout(...))`，同时另产 `battle-ui.json = battleLayout()` | 正式全游戏与独立战斗布局是**两个出口** |
| [`scripts/ui-layout.mjs`](../../scripts/ui-layout.mjs) | `battleLayout()` 的独立 `backdrop` 仍是居中固定宽高，并非全范围拉伸 | 若旧/独立预览候选真的使用这棵树，可作为复现对照；**不等于正式全游戏仍错误** |
| [`scripts/build-native-candidate.mjs`](../../scripts/build-native-candidate.mjs) | 正式候选将生成 `game-ui.json` 传给 `scene_add_client_ui` | 应核验**实际导出的 GIL/客户端加载版本**，不能仅凭 Git 分支名判断 |

静态证据另见：[布局门禁](../../tests/viewport-layout.test.mjs)、[Lua 视口测试](../../tests/lua/viewport.lua)、[旧版红灯和新版通过分层结果](../evidence/mobile-fullbleed-20261025.json)。

**关键限制**：上述测试以给定宿主宽高计算锚点／内容边界，可以证明“如果父级占满这些 UI 单位，子背景也占满”；不能证明实体手机的**最外层原生父级**、实际 `ImageType`、裁切和安全区没有其它限制。之前 `verify:ui` 仍为 6 屏 partial／5 屏 pending；截图和真机均不可借用老候选补作 PASS。

### 显示层级的目标模型

```text
手机物理屏幕（截图像素，不等于 GetUICanvasSize 的 UI 单位）
└─ 平台实际可绘制的 Client UI 宿主（需要真机确认边界）
   ├─ canvasBackdrop：铺满父级，最低视觉层，无命中/交互
   └─ stage：逻辑设计 1280×720，等比缩放且居中
      ├─ 菜单 / 地图 / 战斗 / 商店 / 奖励 / 牌库 / 弹窗等
      └─ 触控区域遵从与舞台相同的坐标变换及安全边距
```

几何表达：`scale = min(canvasW/1280, canvasH/720)`。超宽屏可能存在**内容余量**；自有背景必须覆盖余量。避免将“内容没有横向占满”与“底层世界透出来”混为一谈。

## 3. 先复用同平台成功实践：外部实现与授权边界

以下链接以 2026-10-30 阅读时的公开 `main` 快照为准，复用前须复核对应版本、平台行为和许可证。

| 对照项目 | 值得看哪段具体实现 | 已知证据及局限 | 复用／许可处理 |
| --- | --- | --- | --- |
| [Pairs 翻牌配对小游戏](https://github.com/8itlab/genshin-miliastra-mcp/tree/eb05fd35075b2635e851a2f58b202ac2eadd187b/examples/pairs)（同平台完整卡牌玩法） | [`pairs_win.json`](https://github.com/8itlab/genshin-miliastra-mcp/blob/eb05fd35075b2635e851a2f58b202ac2eadd187b/examples/pairs/pairs_win.json)：`dim` 背景 `size=[0,0]`、`anchor.min=[0,0]`、`anchor.max=[1,1]`；`board`、`hud` 单独定尺寸 | [WALKTHROUGH](https://github.com/8itlab/genshin-miliastra-mcp/blob/eb05fd35075b2635e851a2f58b202ac2eadd187b/examples/pairs/WALKTHROUGH.md) 报告 PC Test Play 跑完整局与手机比例预览；**未证明用户同款实体手机无露底** | MCP 仓库 MIT。最接近我们的游戏：可用作独立 A/B 正向对照，优先复用此简单结构而不是整个框架 |
| [genshin-ugc-webui](https://github.com/zmy15/genshin-ugc-webui/tree/4e003b4eb2ebccb930cc6797eab5e35af4388983) | [`webui_fit.lua`](https://github.com/zmy15/genshin-ugc-webui/blob/4e003b4eb2ebccb930cc6797eab5e35af4388983/lib/webui/webui_fit.lua)：等比缩放、offset、坐标逆变换；[`webui_render.lua`](https://github.com/zmy15/genshin-ugc-webui/blob/4e003b4eb2ebccb930cc6797eab5e35af4388983/lib/webui/webui_render.lua)：`fitBg` 生成四侧底色条 | [`test_fit_fill.lua`](https://github.com/zmy15/genshin-ugc-webui/blob/4e003b4eb2ebccb930cc6797eab5e35af4388983/tests/test_fit_fill.lua) 校验按当前画布 `designSize` 时内部 offset 归零；**离线归零并不等于物理屏幕必无露底** | MIT；仅在证实需要时移植小段几何/诊断方法，保留署名与许可；不引入整套 HTML/CSS 运行时 |
| [MiliUI](https://github.com/MyPingO/MiliUi/tree/04f71a35a13d18a52c6e1d1e5cdf6310ed04362d)（千星 UI 框架） | [ResponsiveLayout](https://github.com/MyPingO/MiliUi/blob/04f71a35a13d18a52c6e1d1e5cdf6310ed04362d/docs/ResponsiveLayout.md)：`UI.Screen` 的全区域 root、独立 padding content、父级相对锚点、比例布局；[`components_screen`](https://github.com/MyPingO/MiliUi/blob/04f71a35a13d18a52c6e1d1e5cdf6310ed04362d/docs/Reference/components_screen.md)：`backgroundStretch`、`screen.root`／`content` | 文档报告 Miliastra Test Play 下的响应式行为；没有针对用户设备的全屏实测证据 | **重要：不是开源许可证**，[`LICENSE`](https://github.com/MyPingO/MiliUi/blob/04f71a35a13d18a52c6e1d1e5cdf6310ed04362d/LICENSE) 限制二次分发/改包装。可参考设计，或依条款使用官方发布包；不可把运行时当 MIT 代码任意拷入自建引擎 |
| [千星官方客户端脚本教程存档](https://act.mihoyo.com/ys/ugc/tutorial/detail/mh47p30a87qo) | [第三方索引出的教学脚本](https://github.com/QHY8IV/miliastra-ugc/blob/e41e6b9f053fbcc078458b4927c867a04e60cc9f/references/live/mh47p30a87qo_official-sample-main.lua)：背景 `ImageType.Stretch`、`SetAsFirstSibling()` | 只能说明官方教学使用图片拉伸与视觉层级；它不是本文同款手机的完整全屏回归 | 教学 `.gil`／官方源码版权归米哈游，供学习对照；不重新分发或整包移植 |

另外，[MCP `src/scene-save.mjs`](https://github.com/8itlab/genshin-miliastra-mcp/blob/eb05fd35075b2635e851a2f58b202ac2eadd187b/src/scene-save.mjs) 描述客户端控件的 `SizeDelta` 是**相对父级 anchors 张开的额外增量**。它是工具作者依据编辑器读回形成的可查证实现，不应被夸大成官方承诺。

### 当前与外部代码的真正差异

- **正面结论**：正式 `canvasBackdrop` 已与 Pairs 的全范围锚点／零尺寸增量一致。因此不能说“别人有标准全屏锚点而我们完全没用”；单纯再重复改 anchors 价值低。
- **候选分叉点**：`battle-ui.json` 独立输出仍用居中固定背景；先查它是否被目标候选实际使用。不能把未部署的测试布局误认生产根因。
- **图片和层级差异**：官方教学显式 `ImageType.Stretch`、置底；可设计为独立测试变量（不要同时变锚点、图片模式、层级）。
- **输入差异**：若背景填满但控件未适配，需以 `screen ↔ design` 逆变换和真机 hitbox 单独验收，不能通过遮罩掩盖错位。

## 4. 唯一建议的优先顺序（先测新版本，再做对照）

### Gate 0：用户最新正式候选是否还露底

用户**尚未测试最新源码**。首先核实当前正式候选来源 SHA、GIL SHA256、平台实际已加载脚本、`ABYSS_UI ready` 日志、手机型号与系统版本、横竖屏方向。正常进入**开局、战斗、地图、奖励／卡组、弹窗**，取同一候选的手机原生截图。先检查有没有可见的蓝天、草地、世界场景漏出。

- **完全没有露底**：该缺陷的复测条件可按 TASK-38 AC#8 保存证据；TASK-38 其它所有 AC 仍须独立验收。不要为预防未来露底而重写核心 UI。
- **依然露底**：不要立即扩大整个 stage、非等比拉伸卡牌或宣称引擎不支持全屏；进入 Gate 1。
- **候选身份不明**：先排查旧包和旧 `external_lua_file`，项目已有只读入口 `scripts/verify-official-client.mjs`；新导入用独立存档，避免将旧外置 Lua 当作新源码（参阅 `.codebuddy/skills/miliastra-wonderland/references/official-client.md`）。

### Gate 1：单变量 A/B，对照同平台成功实现

固定同一台手机、客户端版本、屏幕方向、显示比例／系统缩放、相同截图采集方法；隔离的测试存档不影响正式存档。按下表**逐步**进行，发现明确根因即可停止：

| 编号 | 候选（只改变指定对象） | 区分什么 |
| --- | --- | --- |
| A（基线） | 本项目最新**完整** `game-ui.json` 候选；先记录源头 fingerprint | 真正复现当前问题，而非再次测试旧版 |
| B（正向对照） | Pairs 的`dim` 拉伸背景结构，在同平台原生 Client UI 下使用独立存档 | 同平台相似根容器是否可以覆盖该手机可绘制画布；没有同机结果前只是候选 |
| C（最小化） | 本项目拆出仅 `canvasBackdrop`＋`stage` 的只读独立探针，不加载游戏页面 | 若 C 无边而 A 有边，优先查正式装配、额外遮挡、背景被隐藏和实际页面层级 |
| D（图片变量） | 在 C 的其余字段不变时，对照基础 `image` 与 `ImageType.Stretch` 的原生设置／实际导出存档 | 图片控件框铺满但图片本身不铺满的可能性 |
| E（来源差异） | 检查是否装载了 `battle-ui.json`／旧导入文件、旧外置 Lua；对照正式 `withViewport` 输出 | 甄别构建分叉与部署问题；若证据已确定则无需额外跑一轮设备 |

若所有底层原生 UI 在同一条线被裁切，再查父级／实际绘制画布／设备安全区，并与用户无露底的同平台游戏在相同设备上做截图对照；**不能未经排除即认定平台物理上无法全屏**。也不能从别的游戏成功就直接推断两者的控件类型、UI 宿主和画布 API 完全相同。

### Gate 2：必须收集的最小证据

| 字段 | 记录内容 |
| --- | --- |
| 身份 | 手机型号、系统／原神版本、候选 Git SHA、GIL SHA256、实际加载 Lua 指纹、是否新导入 |
| 尺寸 | 原生截图物理宽高（px）；`GetUICanvasSize()` 实际回报（UI units）；两者禁止混写 |
| 边界 | 截图左／右露底宽度（px）及各自占比；颜色边界、出现在哪些页面 |
| 结构 | 实际宿主／根／背景 `anchorMin, anchorMax, sizeDelta, pivot, localScale, visible, imageType`；是否 mask／父级裁切 |
| 对照 | A 与 B／C 的同设备截图、明确不同的变量、是否等效边缘 |
| 输入 | 刘海安全区、左右按钮触点是否命中、缩放后光标坐标是否换算一致 |
| 结果 | `PASS`／`FAIL`／`NOT_TESTED`；失败的来源候选、日志和截图路径；下轮唯一动作 |

**验收分层**：源码／模拟测试通过 ≠ 导出 GIL 完整 ≠ 官方预览 ≠ PC 试玩 ≠ 目标实体手机无露底与可触达。已运行的层只记录已运行证据；不挪用别的 SHA、旧截图、旧 FPS 或未运行的外部例子。

**建议实际可观察标准**：目标手机上的**可绘制游戏区域**，菜单／战斗／地图／节点／弹窗无底层世界穿透；内容及可点击区域保持安全区和同一坐标变换，不卡牌变形。系统黑色胶囊、手势栏或平台明确不可绘制区域独立标注，不能凭“黑色像素”就当成失败。

## 5. 故障分支与决策

| A/B 现象 | 推断（待日志印证） | 下一动作 |
| --- | --- | --- |
| 最新版 A 无露底 | PR207 很可能已覆盖原缺陷 | 保留当前方案，继续 TASK-38 同候选其它 UI/触摸验收；不再开发 fullscreen 特性 |
| A 露底、B 与 C 不露底 | 我们的正式构建／层级／图片配置更可疑 | 比对实际 GIL 容器树、imageType、背景 active/visible/sibling 与 mask |
| A 露底、C 不露底，B 未测 | 战斗/页面组合或部署路径更可疑 | 从 A 到 C 做最小差异逐项恢复，不先改缩放公式 |
| A/B/C 都在相同边界露底 | 原生父画布／安全区／平台宿主边界需排查 | 真机记录物理像素与 UI units、独立高层根／宿主探针，不夸大为已证实平台限制 |
| 图片铺满但人物／牌堆显得窄 | 背景覆盖和 16:9 内容布局是两件事 | 背景保持全屏，仅在需要时评估响应式内容重排，不拉伸卡图 |
| 屏幕外观已满，点击偏移 | 画面与输入逆变换／安全区不一致 | 单独复核坐标转换和原生 hitbox，避免只调整视觉 |

## 6. 执行边界和交接

1. 本报告**只提供现成的诊断路线**。用户未测最新正式包，不触发新实现、不强迫本轮 A/B；不建新的 fullbleed 任务，复用 TASK-38 AC#8／TASK-4。
2. 首轮最低成本是**最新包同机截图**。确认仍有露底后才追加 Pairs、最小探针；避免为一次可能已解决的 Bug 把多个外部 UI 运行时打包进生产。
3. 任意导入、官方预览、游戏窗口置前或输入操作之前，按 `AGENTS.md` 与官方客户端指引先取得用户**本轮明确的键鼠使用窗口**。不碰正式存档、不抢占其它 Agent 会话；源码、导出、官方运行和手机验证分开记。
4. 许可：MCP / genshin-ugc-webui 是 MIT，可按其许可证精确引用及保留 NOTICE；MiliUI 不是开源，只按官方发行和 Usage Terms 使用；米哈游官方教学代码／存档不作为可再分发来源。
5. 若用户报告复现，接手 Agent 先读此文及 `TASK-38.md`、`MOBILE-QA-20261029.md`、`mobile-fullbleed-20261025.json`，核对**当时最新 develop** 后再选择实验，不以本报告的固定 SHA 代替实时分支读回。
