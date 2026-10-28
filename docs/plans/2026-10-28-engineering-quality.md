# 工程质量验收实施计划

> 按已批准的方案1执行。使用 writing-plans / executing-plans；本轮在主线程顺序实施，不委派或改玩法。

**Goal:** 复用 Lua AST、固定 Luacheck 和架构检查，交付完整、可复核、先报告后启用新门槛的质量机制。

**Architecture:** 独立质量入口调用现有检查器的采集 API，所有数据本轮重新测量，不信任 build 中残留报告。逐个 AST 函数（含匿名、嵌套）及初始化块核对 Luacheck 坐标；既有架构硬门禁与完整依赖图 SCC 报告分开。冻结基线绑定源码与检测口径，差异按模块和函数展示；新增指标保持报告模式。

**Tech Stack:** Node.js、luaparse 0.3.1、Luacheck 1.2.0、node:test；不加依赖。

## 验收与范围

- 全量 src/lua 递归发现；不得按大小/名称排除文件。指定模块固定为 combat、battle_ui、node_ui、run、nodes、game_ui、feedback；同时全量报告辅助模块。
- 文件物理行包括空行、注释，末尾换行不额外计行。函数跨度为完整 AST 起止行，含嵌套函数；构造器只作名称标签，所有长函数同样展示，改名不会消失。
- 圈复杂度仅使用 Luacheck 数值。每个函数/初始化块恰好一个测量；重复、错位、漏测、未知文件/格式或解析失败均非零。
- 完整依赖环使用现有 AST 边计算强连通分量，包含延迟 require，保留实际内部边。既有延迟导入策略不改；完整环先报告。
- 静态告警的新增、移除、原样保留逐条列出，沿用精确坐标身份；不自动迁移告警或更新旧基线。
- 基线不可自动更新；口径/工具版本不匹配失败，模块删除及函数消失明确列出，不算自动达标。不添加排除、白名单，不修改生产 Lua。
- 新行数/跨度/全库复杂度/完整环上限暂不启用；后续启用必须有独立重构的最终值、全部辅助职责审查和回归证据，另行审查规则提交。

## 步骤

1. `tests/engineering-quality.test.mjs`：先写物理行、嵌套/匿名函数、中文列坐标、main与首位函数同坐标、漏测/重复/错位、完整环、静态增减、口径不匹配和新增辅助模块的负例。运行确认功能尚未存在。
2. `scripts/lua-quality-metrics.mjs`：实现 AST 测量映射与完整 SCC；复用现有 parseDiagnostics、checkArchitecture、runStatic，不自写复杂度算法。运行第一批测试。
3. `scripts/check-engineering-quality.mjs`：新鲜采集、冻结基线比较与 JSON/Markdown 报告；报告新指标债务不因超标退出，但完整性错误及既有架构/静态新增错误不能写成通过。CLI 只允许基线输入路径，无刷新/排除/阈值放宽选项。
4. `config/engineering-quality-baseline.json`：从固定 develop@1f260a71 源码生成一次完整快照（保留完整数据，不作豁免）；加 `check:quality`，接入原 `check:engineering`；CI 上传本轮报告与失败诊断，不改已有必需作业/时限。
5. `docs/ENGINEERING_QUALITY.md` 与 `docs/ENGINEERING.md`：写真实基线、命令、报告含义、后续硬门槛启用条件和人工职责审查边界。工具只能发现数值/结构变化，不能证明拆分具有业务意义。
6. 验证：工具专项测试 + 原 architecture/lua-static/ui-complexity/responsibility-complexity 测试；运行实际 `check:architecture`、`check:lua-static`、`check:quality`，核对源 Lua diff 为空与基线一致。CI 全套和平台状态按实际证据报告，不推断通过。
