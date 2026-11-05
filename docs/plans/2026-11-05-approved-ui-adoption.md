# 已认可 UI 设计采用计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将已认可的最新设计作为可运行且来源清楚的正式接入基准入库。

**Architecture:** 从最新 develop 独立分支集成已有公开原型，并同步最新私人版本的结算与无存档交互。第三方画面继续隔离，正式 Lua、主题、Host、Backlog 认领和能力开关不在本批修改。

**Tech Stack:** 原生 HTML/CSS/ES modules、Node test runner、现有 GitHub Full/merge:auto。

**Spec:** `docs/design/APPROVED_UI_ADOPTION_20261105.md`。

## Global Constraints

- 不重新设计已认可样式，不改变正式游戏规则；HTML 不是千星原生实现。
- 不新增依赖、CI 作业或并行任务系统，不抢已有 owner，不改 #516 的 Host/队列。
- 原版图片、嵌图 SVG 和新彩蛋图不进入公开目录；保留来源及 OFL 许可。
- 不自动发布；合并须独立审查与精确 HEAD/BASE 完整门禁。

## Review Focus

- 刷新/退出不能恢复不存在的持久存档；覆盖模块实例隔离与页面可见入口。
- 失败不能出现胜利彩蛋；覆盖结果模型与实际页面。
- 结算不得伪造平台提交；检查可见提示及返回。
- 模态取消、重复开关不得破坏底层场景与焦点；在隔离云预览回归。
- 隐含图片族或嵌图不能带回第三方像素；资源清单/摘要/本地引用回归。

## 1. 同步现有设计与采用边界

- [x] 固定远端公开来源和最新私人来源；核最新 develop、开放 PR 与任务 owner。
- [x] 先接入结果模型/内存态测试，观察旧公开版本因缺失实现出现 4 项失败。
- [x] 同步已实现的结果/菜单/内存态代码，保持公开几何替代资源，13 项初始原型合同通过，审查修复后扩至 15 项。
- [x] 更新采用记录、原型来源与主设计入口；纠正候选 CLI 与底层 API 的美术默认值差异。
- [ ] 已核主菜单、结算胜败、来源/平台说明及返回；退出残留先浏览器复现后单元回归修复。修复后浏览器复测被权限检查停止，卡牌视觉、重开与键盘回归仍待，不宣称可视验收完成。

## 2. 审查与正式合流

- [ ] 独立审查完整改动；按发现做最小修复后复测。
- [ ] 通过可运行的本地门禁并开 Draft PR，核远端提交树与差异范围。
- [ ] 当前 HEAD/BASE Full 与 merge:auto 原入口通过才转入合并队列；若 CLI/认证不足，保留 Draft 并报告实际阻塞，不直接合并绕过。
- [ ] 合后核 squash 提交与 push Full；原生候选/设备验收继续保持未完成。
