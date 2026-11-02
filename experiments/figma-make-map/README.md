# Figma Make 爬塔地图 · 源码参考快照

本目录仅保存 **2026-11-02 用户 Figma Make 实验的可核实代码片段**，供 Milestone 4 设计比较和千星奇域原生 UI 移植研究。

## 来源和可看效果

- [Figma Make 编辑项目](https://www.figma.com/make/lBvCW0LPBHzBd39mGhMUQy/%E8%AE%BE%E8%AE%A1%E4%BA%A4%E4%BA%92%E5%BC%8F%E7%88%AC%E5%A1%94%E5%9C%B0%E5%9B%BE?t=JNuGT1nSMBT3uu6T-1)
- [Figma Site 发布后的可交互预览](https://app-spill-35276825.figma.site/)
- [Google AI Studio 对比实验](https://aistudio.google.com/apps/0706af48-2f17-49c3-86f9-d20db0740450?showPreview=true&showAssistant=true)
- [提取步骤、证据范围与现行原生规范对照](../../docs/research/figma-make-map-2026-11-02.md)

## 快照内容

`source/src/App.tsx`、`map.ts`、`icons.tsx`、`index.css` 为 **Figma Make AI 执行日志中实际写入文件的源码**。先从已授权浏览器标签读取完整 Shell 命令，解码页面 HTML 转义后写入独立实验目录，随后逐文件重新读取 GitHub，并与本次提取结果逐字符核对，**4/4 一致**。

这**不是** Figma 官方源码 ZIP，也不包含 Make 的完整脚手架（`package.json`、锁文件、入口 `main.tsx`、`index.html` 等）。目录**不可据此声称能直接运行**，更不能证明千星奇域平台兼容。对源码的重建、依赖、渲染或修改都应在独立副本中完成。

临时 SVG 图标是 Make 生成的演示替代品，不是千星奇域官方图库；不能直接替换现有正式图标。不得将 Web/CSS 光效直接当成原生控件能力；以当前项目约束及实机验收为准。

**没有修改游戏运行代码、主题或发布分支。** 不因归档实验源码而改变现有项目或第三方素材的授权边界。
