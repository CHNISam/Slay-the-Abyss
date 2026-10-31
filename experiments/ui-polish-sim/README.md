# ui-polish-sim 证据分层

| 路径 | 证明什么 | 不能证明什么 |
|---|---|---|
| `render.mjs`（HTML 占位 glyph） | 布局/层级/文本 | 官方贴图、动效 |
| `sim.mjs`（Beyond Simulator 单帧，无脚本） | 官方贴图下的静帧：字色、图标、层级 | **任何动效**（存档清空了 scripts） |
| `motion.mjs`（本次新增） | 生产 Lua `abyss_map_ui` 的 `update(dt)` 真实推进 MapRoomNode 呼吸（scale/alpha），逐帧解析控件树后交给 Simulator 渲染 t0..tN + GIF | 帧间插值/帧率/卡顿、真机点击手感、Simulator 内部脚本计时 |
| 真机（PC/手机） | 帧率、触控、选中流畅度、最终验收 | — |

`motion.mjs` 的动效**数值**来自生产代码（宿主 fixture 驱动 update），**像素**来自 Simulator 官方贴图；
并非在 Simulator 里跑 Lua。若需 Simulator 内跑脚本，参照 `art-tech-lab`（interaction.lua + `qxqy_studio_play click`），
但完整 GameUI 存档较重，未做。

运行：`node experiments/ui-polish-sim/motion.mjs [outDir]`（env `MOTION_FRAMES`=4，`MOTION_STEP`=0.35s；需 ffmpeg 出 GIF）。
输出：`motion-t*.sim.png`、`motion.gif`、`frames.log`（每帧可达节点 scale/alpha）。

## 选中/当前闪圈（motion-flash.mjs）
`node experiments/ui-polish-sim/motion-flash.mjs` → `.artifacts/map413/v3/motion-flash/`（choose→战斗胜利→回地图后 t0..t3）。
结论：**当前代码没有任何定时闪圈**。`abyss_map_ui.lua`：L376 变 current 时 `fx.scale` 直接置为 baseScale（无过渡）；
L396 `ring.localRotationZ = fx.angle`（angle 由 id 哈希固定，L110）；update 只对 available 调 `oscillate`，其余 `scaleLerpSnap` 到已等值的 baseScale（L468-471）。
`frames.log` 证实 current ring 各帧 scale=0.500/rot=163/size=51.03 不变；帧间像素差只来自下一排可达节点呼吸。
choose 同步进入战斗（`after-choose phase=combat`），地图上不存在可截的"选中中间态"。要有闪圈需新写动效（STS 原版亦无旋转闪圈，仅 circle 静态 + 可达节点呼吸）。
