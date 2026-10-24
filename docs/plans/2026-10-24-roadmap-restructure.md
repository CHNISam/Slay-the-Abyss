# 《杀戮原塔2》路线图迁移 Implementation Plan

> 按用户已批准的产品路线图在当前会话顺序执行；不委派子代理，不扩大产品实现范围。

**Goal:** 将首发成果分为M0–M6，分离基础通关、内容齐备、正式品质和RC验收，并独立跟踪E1–E5。

**Architecture:** 从最新develop隔离，先经CLI审计现有任务/Draft/依赖与PR，再经CLI迁移。保留Done文件、历史证据和进行中/Blocked状态；文档统一引用新的成果关口。

**Tech Stack:** Backlog.md CLI、Git worktree、Markdown、GitHub Quality。

1. 冻结107项任务迁移前快照；核查开放PR、PR147、Draft及本地脏文件。
2. CLI重命名Milestone并设日期；拆分17/12.3，复用规则专项及Draft，修正依赖和未分配任务。
3. 更新MILESTONES、SCOPE、AGENTS及受影响交接/投稿引用；输出任务树、状态、日期、证据和迁移对照。
4. CLI读回、doctor、Done文件/状态/依赖/AC保全检查和diff检查；PR当前SHA的Quality全绿后合并。

验证只覆盖管理变更；不据此宣称游戏、UI或投稿通过。代码、存档、截图及历史实机日志保持原样。
