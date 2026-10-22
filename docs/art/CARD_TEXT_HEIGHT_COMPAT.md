# TASK-10.1：原生短文本框高度兼容候选

本候选针对原版实机截图：卡框、岩晶、费用「1」和说明「造成 6 点伤害。」可见，标题「打击」与类型「攻击」缺失。**2026-10-23用户导入v2后官方试玩，两处文字已正常显示，点击更新通过。** 上游原始输出完整保留在 [`art/spikes/card-editor/`](../../art/spikes/card-editor/)，高度兼容稿放在 [`text-height-compat/`](../../art/spikes/card-editor/text-height-compat/)。制作范围见 [CARD_PRODUCTION.md](CARD_PRODUCTION.md)。

## 已知证据与假设

- 截图由主 Agent 提供：`codex-clipboard-UfuVVv.png`，SHA-256 `8c264f3cf344a17e5ca358569dccc4ba0ba96301382d4d3db5a782dd560c15f8`。本 Agent 仅查看本地截图，不操作游戏或官方存档。图中缺失两项与主 Agent 描述一致；此处不推断其存档 ID 或导入日志。
- 原始 JSON/Lua/GIA 都保存了正确的标题/类型 UTF-8、`visible=true`、透明背景、正确颜色和居中对齐；层序在图形背景之后。费用和说明使用同一上游文本框路径，实机已显示，故不存在全部中文均被账号等级屏蔽的现象。
- 本机官方客户端 API 加工快照 `D:/MiliastraTools/genshin-miliastra-mcp/knowledge/official/guide/mhtakr07vej4.md:747–764` 公开了 `fontSize`、`adaptiveFontSize`、`minimumFontSize`、`verticalAlignment`；`:658–666` 公开 `SetAnchoredPosition`、`SetSizeDelta`、锚点和轴心。**文本框没有公开 padding 设置或最小高度公式**，不能声称已知内部留白的精确值。`GetPadding` 属于后面的网格控件，不应给文本框调用。
- 原版实机中，缺失项分别为 h22/font17、h18/font14，显示项为 h40/font22、h92/font15。仅改高度的v2两处均显示，支持短框容纳问题；未测内部留白公式或精确最小高度。

## 唯一改动

| 元素 | 原透明框高度 | 候选高度 | 中心、字号及其他属性 |
|---|---:|---:|---|
| `card-title` | 22 | 40 | 保持中心(90,33)，字号17 |
| `card-type` | 18 | 40 | 保持中心(90,121)，字号14 |
| `card-description` | 92 | 92 | 原样 |
| `card-cost` | 40 | 40 | 原样 |

40来自这次实机已显示的费用文本框高度，**不是已测出的平台最小高度常数**。扩大的是透明文本框的布局容纳区域，名称条30高、类型条18高等全部背景几何保持原样；固定中心和 `alignV=middle`，不改字形中心、字号、颜色、宽度、锚点、轴心、自适应设置、内容或层序，也不新增遮罩。文本框没有交互事件，不扩大任何出牌点击区域。

适配仅位于本实验的 `native_text_height_candidate(source)`：深复制场景，改上述两个 `height`，然后继续调用固定提交的**原上游**导出函数。无手写 Lua/GIA 转换器，无导出器修改，无核心 UI/主题/原型修改。原始路径输出没有覆盖。

## 复现与本地回归

在 `.worktrees/art-card-spike` 根运行（沿用 [`CARD_EDITOR_SPIKE.md`](CARD_EDITOR_SPIKE.md) 已固定的上游提交/venv）：

```powershell
$editorRoot = 'F:/New folder/tools/vendor/image-editor'
$exportPython = "$editorRoot/backend/.venv/Scripts/python.exe"
& $exportPython scripts/art/test-card-text-height-compat.py -v
& $exportPython scripts/art/export-card-spike.py --editor $editorRoot --text-height-compat
node "$editorRoot/backend/tests/check_textbox_lua.cjs" `
  'F:/New folder/.worktrees/battle-ui/node_modules/fengari' `
  art/spikes/card-editor/text-height-compat/card.lua `
  art/spikes/card-editor/text-height-compat/card.json
```

已执行：2项几何回归先在适配函数不存在时失败，加入适配后通过；断言输入不变、仅2个高度改变、所有中心/文本/字体/样式/层序均保持，以及重复适配结果不变。另1项回归比较实际导出的两份规范化 JSON，仅允许这2个高度变化，并比较两份 PNG 字节；合计3项通过。候选经原上游完成 JSON/Lua 回导；独立 GIA 二进制读取核对4个原生文本框的中心与尺寸、UTF-8、11个图片图元及顺序。Fengari 15控件契约通过，检查实际生成的Lua，不依赖手改运行时。

原始与候选上游 PNG **逐字节相同**，SHA-256 都为 `6248e99c7ca25359eb5e31a2da78fbf3f9ea4eaf4b6e2fdb10ba6c9c25b3c72d`，也已目视检查。它只证明上游 Pillow 的居中预览没改变外观；该预览没有复现平台短框不显示的问题，因此不能作为原生渲染修复证据。候选版本/哈希/检查见 [`verification.json`](../../art/spikes/card-editor/text-height-compat/verification.json)。

## 主 Agent 实机复验

候选脚本：[`text-height-compat/card.lua`](../../art/spikes/card-editor/text-height-compat/card.lua)，仍保留 `IMAGE_PREFAB_ID=0`、`TEXTBOX_PREFAB_ID=0`；沿用已实机成功的挂接过程和真实模板索引，仅替换这份导出候选。对应的 JSON/GIA 也在同目录，资源组名保持原样；使用干净副本或替换同一显示脚本，不同时导入两张来比较。

复验只检查：标题「打击」与类型「攻击」是否出现，是否仍位于名称条/类型条中心，以及费用、说明和岩晶是否与原截图一致。需要保存新截图和运行结果；若仍不显示，先读回两个实例的 `text`、`fontSize`、`minimumFontSize`、`adaptiveFontSize`、`GetSizeDelta()` 与 `GetAnchoredPosition()`，确认运行的是40高候选，再检验其他假设，避免同时改字号、对齐和模板。

| 层 | 当前证据 |
|---|---|
| 原始小样实机 | 主 Agent 反馈已运行，图元/费用/说明可见，标题/类型失败 |
| 高度候选本地导出与格式/VM契约 | 通过 |
| 高度候选平台静态检查 | MCP 0错误/0警告，不单独声称官方编译日志通过 |
| 高度候选导入/写入存档副本 | 主 Agent 已准备副本；用户已导入并进入官方试玩 |
| 高度候选原生文字实机显示 | 用户两张截图确认标题/类型/费用/说明/图形；点击更新通过 |
| 中央 Backlog / 正式存档 / 发布 | 主 Agent 完成单卡门槛TASK-10.1.1；未发布，父Spike仍在进行 |

v2截图SHA为03a3e3627dc87c94b86116ea8649d9700efcc5cf49a58bff27eccc826043a555、1fdaba4d6c080e0330b60ae41b30398c06bf48817b6664b999dc31668fa6df52。10秒回调dt均值33.3/P95 34.0ms，非GPU耗时；没有基线/多卡/目标设备结论。只按制作规范放行少量通用卡牌资产，不关闭父TASK-10.1。
