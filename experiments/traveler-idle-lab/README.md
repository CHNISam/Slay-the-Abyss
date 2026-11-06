# 旅行者与岩苔怪：原生分层动画实验

用户授权的独立实验，基于 develop `87c944f3d1ae89b01470cf89d6f7cc96cc4017ab`。
仅新增本目录，不改生产战斗、#519 的 UI、任务队列、Sprint 或默认美术，不合并/发布。

## 看什么

- 旅行者（空）的金发辫、白金披风、黑金衣装被重新画成原生基础图元；这是简化几何稿，不是原画同画质还原。
- 岩苔怪是本实验原创造型。双脚扎根，上身与两侧手臂错相摆动。
- 默认仅待机：头、身体、发辫、披风、持剑手与眨眼独立运动。没有逐帧图片、外部贴图或逐帧创建控件。
- 「旅行者出招」「怪物出招」演示朝向位移、接触击退和短促闪光；反复点选取代当前演出，不形成无上限队列。「自动演示」每两秒交替出招；「重置为待机」立即终止动作并归位。
- 动作只控制实验场景，不结算伤害、不调用战斗命令。没有新攻击/受击角色图。

## 明确参照与区别

1. **StS1 Ironclad 的常驻待机**：分层、脚底锚定、小幅身体起伏。BaseMod 作者指南说明 Spine 分层和 30fps 作者时间基准：[Custom Character Animations](https://github.com/daviscook477/BaseMod/wiki/Custom-Character-Animations)。本实验不是 Spine runtime，也不声称逐帧复刻原版。
2. **StS1 Cultist 的 `waving`**：原版名称与资源位置由 [PuzzleMod 作者文档](https://github.com/will-snavely/PuzzleMod/wiki/Building-Puzzles#without-a-template) 确认。仅取其常驻肢体摆动机制，没有复制面具、羽衣或原纹理。
3. 原版攻击/受击对照：[AbstractCreature.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java)。方向性偏移、独立计时、终止归零是参考；不照搬原版 90px 振幅。
4. 实验出招复用本仓库 `src/lua/abyss_feedback.lua` 与 `abyss_feedback_actor_painter.lua` 在上述基线的表现参数：`0→-8→+16→0`、时间 `0/.06/.20/.55s`、smoothstep；轻击向外12px、.05s停顿、.20s平方缓出；闪光.12s衰减。怪物镜像同一轻量攻击；没有复制生产怪物蓄力逻辑，也未接整个生产反馈模块。

待机 2.8/3.2/3.4 秒周期、2–3px 幅度与错相是本实验原创调参，**不是测得的原版周期**。闪光用预建的基本形状复用，不再生成素材。未包含摄像机震动、音效、血条、战斗队列或新受击帧。

## 本地最快尝试

1. 先打开 `preview.png` 与 `demo.mp4` 看几何稿是否值得进游戏测试。视频是实际 Host 截图按30Hz模拟步进编码，**不是实时GPU录屏或设备帧率证明**。
2. 在 BeyondSimulator 0.5.2 打开 `sample.save.json`，运行后点击底部按钮。脚本随存档存在。
3. 官方千星沙箱：只在**独立空白存档副本**中导入 `import/` 中服务器控件模板 GIA 与脚本 GIA。不要覆盖现有项目，不自动发布。
4. 导出器明确不保留脚本挂载。导入后把 `idle.lua` 对应客户端脚本重新挂到根容器 `TravelerIdleLab`，保留内部 `traveler/monster` 与按钮名称。脚本 GUID 仅是导出身份，不保证官方导入后不重新分配。
5. 将根模板放入可见界面后启动当前候选；日志应有 `traveler-idle-lab-ready:original-primitives:87c944f3`。没有新日志/当前画面就不能认定成功。若 GIA 或客户端 API 不兼容，保留报错，勿替换生产内容。
6. 先看30秒待机，再双向点击各10次、连续点击打断、重置、关闭重开。确认脚底不漂移、回到原位、无残留闪光；之后再测手机。记录候选 SHA256、官方容量、设备和实际帧时间。

**官方导入、脚本重挂、新ready、官方容量、PC游戏与实体手机均未验证。** Simulator 通过不表示上面任何一项已通过。GIA导出只是候选文件，不能承诺可直接运行。

## 复现

Node 24，锁定 `beyond-simulator-mcp@0.5.2`。可复用已有安装，或在本目录外用 npm 安装到专用 runtime。设置 `ART_LAB_MCP_ENTRY` 为其 `dist/index.js` 的绝对路径；`XDG_CACHE_HOME` 指向可写缓存。

在本目录运行：

```sh
node build.mjs
node verify.mjs
ffmpeg -framerate 30 -i frames/%03d.png -c:v libx264 -pix_fmt yuv420p -movflags +faststart demo.mp4
```

`verify.mjs` 用真实 MCP/Lua Host 执行，无键鼠输入、无用户桌面。它重建 `frames/`、验证证据和 `import/`；运行后检查 `verification.json` 没有 failure。`inventory.json` 是生成控件计数；`verification.json` 记录本轮断言、RPC指标与导出警告。RPC耗时包含进程通信，不是GPU帧时间；控件不增长也不证明内部堆无泄漏。

## 资源与许可

所有图形用官方矩形、圆形、三角形、星形图元手工组合。没有使用或打包用户发来的原画/伪GIF、StS角色纹理、官方图库纹理原文件或第三方字体。旅行者角色形象仍属原权利人；此处重绘不转让其角色权利。实验源码遵循仓库根 `LICENSE`，不改变项目非商业/商业权利约定。

## 验证范围

本轮针对独立样品执行 Node 语法检查与 `verify.mjs`。最终文件的实际数值以 `inventory.json` / `verification.json` 为准（157控件，其中124基本形状图片）。仅已运行定向验证，未运行整个仓库的 npm test / Full CI，不声称正式准入或合并就绪。源文件和原始 save 的 SHA256 以候选证据为准。
