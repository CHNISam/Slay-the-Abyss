# M4 · Figma Make 交互式爬塔地图实验（2026-11-02）

> **性质：外部原型参考 / 证据记录，非游戏可导入源码，非已批准的 Lua/GIL 实现。**
> 用户实测认为这版 Figma Make 地图的视觉、交互效果优于本轮 Google AI Studio 对照，优先作为 Milestone 4 地图设计实验的**视觉质量参考**；原有游戏规则、官方图库资产决策与原生平台验收仍以仓库现行规范为准。

## 原始链接（均为用户提供或本轮浏览器已访问）

| 资源 | 链接 | 用途 |
| --- | --- | --- |
| **Figma Make 可编辑项目** | [设计交互式爬塔地图](https://www.figma.com/make/lBvCW0LPBHzBd39mGhMUQy/%E8%AE%BE%E8%AE%A1%E4%BA%A4%E4%BA%92%E5%BC%8F%E7%88%AC%E5%A1%94%E5%9C%B0%E5%9B%BE?t=JNuGT1nSMBT3uu6T-1) | 查看生成记录、编辑器和项目上下文；访问受文件权限约束 |
| **Figma Site 已发布原型** | [交互式爬塔地图·运行预览](https://app-spill-35276825.figma.site/) | 浏览器打开并操作实际网页原型；这是发布站点，不是源码仓库 |
| **Google AI Studio 对照** | [Slay the Abyss — Roguelike Map](https://aistudio.google.com/apps/0706af48-2f17-49c3-86f9-d20db0740450?showPreview=true&showAssistant=true) | 同主题设计实验对照；权限和当前版本需复核 |
| **本项目批准稿** | [Map.dc.html](https://github.com/CHNISam/Slay-the-Abyss/blob/develop/docs/design/ui-canvas/Map.dc.html) | 旧画布快照与当前约束对照，不能替代较新的明确决定 |
| **本项目现行设计决定** | [ui-canvas/README.md](https://github.com/CHNISam/Slay-the-Abyss/blob/develop/docs/design/ui-canvas/README.md) | 2026-10-28 等后续决定优先 |
| **原生地图实现边界** | [MAP_IMPLEMENTATION.md](https://github.com/CHNISam/Slay-the-Abyss/blob/develop/docs/design/MAP_IMPLEMENTATION.md) | Lua / Map.view / Map.available / 千星奇域控件约束 |
| **并行设计工具评估** | [PR #464](https://github.com/CHNISam/Slay-the-Abyss/pull/464) | M4 工具实验与 TASK-95 的待合入规划；不阻塞其他工程修复 |

## 已核实内容与证据边界

- 在已获授权的用户浏览器标签中，曾**实际读取到** Figma Make 的 AI 执行日志与项目内容。日志载有四个主要生成文件的完整写入命令：`src/App.tsx`、`src/map.ts`、`src/icons.tsx`、`src/index.css`。AI 汇总为四文件约 **769 行新增**，保存为 Make Version 1（Make 内部版本标识 `886c6f6901b6f12c91ecb085c93bc08637f3289e`，**不是 GitHub commit**）。
- 执行日志显示 Make 成功 HTTP 200 下载项目三份设计参考文件（`ui-canvas/README.md`、`Map.dc.html`、`MAP_IMPLEMENTATION.md`）；作者说明没有逐字通读，不应把这视作规范完全一致。
- 生成代码为 React / TSX / CSS 的网页模拟原型：15 层分叉地图、七类节点、已走过/当前位置/可前往/不可达、悬停路径预览、合法选择反馈、纵向滚动/拖拽、地图图例、HUD 与响应式处理。节点图标为临时代用的 SVG，**不是**千星奇域官方图标。
- 浏览器曾直接读取 `figma.site` 运行页面的 DOM，确认存在第 1～15 层节点和七类图例等控件。**尚未取得可核验的渲染截图、逐项人工点击证据或移动端实机测试**，不宣称已完成视觉/交互验收。
- **已在本 PR 归档四个核心文件**至 [`experiments/figma-make-map/source/src/`](../../experiments/figma-make-map/source/src/)，来源为本次 Make AI **Shell 写入命令的完整文本**（已恢复用户浏览器标签读取）；每个文件均提取、按源码字面解码 HTML 转义并在 GitHub 写入后重新读取，四份内容的逐字符比较全部一致。**但并非 Figma 官方导出的项目 ZIP**：`package.json`、锁文件、`index.html`、Vite/构建配置等尚未获取，不声称快照可直接独立启动，也不能证明当前 Make 文件后来没有修改。

## 给后续移植实验的最小交接

1. 以 **Figma Site 实际效果**评审视觉层级、暗岩/琥珀金材质、图例、节点状态、路线流光、滚动与选择手感；Figma Make 文件用于追溯 TSX/CSS 原实现。
2. 与当前 `develop` 的真实 `Map.view` / `Map.available` / 官方图库和现有 UI 组件对照，**只迁移表现，不改游戏地图生成、房间规则与已批准交互**。
3. 保留「网页原型 / Lua 静态验证 / 千星奇域实际导入 / 真机截图与交互」四层证据界限。新视觉品质须由实际画面证明，不用源代码存在或 HTML 能运行替代游戏验收。
4. 后续真正拿到源码时，在独立隔离的实验目录保存带来源的快照、核对文件完整性与依赖，再考虑移植；不得直接覆盖生产 Lua/HUD 或修改发布分支。

**当前状态：** 参考链接、运行 DOM 及从 AI 日志提取的四个核心源码文件已核实、归档与读回一致；**整个 Figma Make 项目完整导出**（含工程配置/依赖）、浏览器渲染截图、原生移植与实机验证均为 **未完成**。
