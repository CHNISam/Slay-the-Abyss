# 单张卡牌导出最小实验 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 复用用户指定的 Miliastra Image Editor 上游导出器，交付一张可继续编辑、含原生中文文本的岩荧风格卡牌小样。

**Architecture:** 输入使用上游 SceneDocument JSON，直接调用其后端 JSON/Lua/GIA/PNG 出口；不引入新的编辑器、转换框架或游戏逻辑。外观以已批准 PR #19 的卡牌规格与主题为准，卡图只用几何岩晶占位。真实控件模板索引由主 Agent 独占的官方编辑器会话取得。

**Tech Stack:** Python 3.13、上游 FastAPI/Pillow 后端、现有主题 JSON。

## 范围与执行

1. 阅读上游技术说明、模型和导出实现，固定提交与隔离依赖。
2. 在 `art/spikes/card-editor/` 保存一张 148×208 卡牌的源与上游导出结果。画布额外留出费用圆溢出空间。
3. 提供 `scripts/art/export-card-spike.py`，仅构造本小样数据并调用上游导出函数，禁止复制或改造上游实现。
4. 检查 JSON/Lua 回导、GIA 解析、坐标与图元顺序，运行上游相关契约检查；目视检查上游 PNG。
5. 在 `docs/art/CARD_EDITOR_SPIKE.md` 记录复现、模板/API/坐标契约、许可证、平台适配与证据边界；提交独立 draft PR。

## 已批准设计的具体应用

- 148×208、2px 基础灰框、深岩灰蓝底、30px 名称条、64px 暗红攻击插图区、18px 类型条。
- 费用直径40、琥珀底、数字22；中文标题17、效果15，最小14。
- 内容只从 `data/cards.json` 的 `strike` 读取，插图仅琥珀岩晶几何占位，不表示新增元素机制。
- 原生文本保留中文字符串，不把文字烘焙为图形。无 Prefab、活动蒙版、拉伸、旋转X/Y、动画或交互。
- 此任务已有明确范围及批准视觉基线，执行单个样例；真机前不得推广到整套卡牌。

## 验证与交接

- 上游 JSON/Lua 数据回导必须保留文本、尺寸与层序；独立 GIA 读取器检查图片记录及文本框消息数量。
- PNG 只证明后端预览可绘制；模板索引、平台编译、存档导入、游戏文字与显示须分别由主 Agent 验证。
- 不更新根 Backlog，不操作 GUI/MCP/实机，不修改核心 Lua 或批准原型。
