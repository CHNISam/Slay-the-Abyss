# 自动化检查与本机 runner

仓库：CHNISam/Slay-the-Abyss。专用 runner：`slay-the-abyss-windows`；
标签：`self-hosted`, `Windows`, `X64`, `slay-the-abyss`。
安装目录：`C:\actions-runner-slay-the-abyss`，工作目录为其 `_work`。
Windows 服务：`actions.runner.CHNISam-Slay-the-Abyss.slay-the-abyss-windows`，
使用 Network Service 账户，自动启动；与其他项目 runner 分开安装。

## 每次变更

从 develop 建 feat/* 分支，通过 PR squash 合并回 develop。
PR 标题使用 Conventional Commits；master 仅收 release/hotfix 并打 tag。
Quality / check 在 PR、develop/master 推送时运行，也支持手动执行：

1. 检查本次变更的空白错误和 PR 标题。
2. Node 22 JavaScript 语法检查。
3. Node 自动化测试（串行执行，失败立即阻止通过）。
4. 所有运行数据的结构、枚举、范围、ID 与交叉引用校验。

本地使用 `npm run check`，无第三方 npm 依赖，无需 npm install。
本机直接使用已安装的 Node 22，并在每次作业开头验证主版本；fork PR 的
Ubuntu 才执行 setup-node，避免本机每次初始化额外下载工具链。
编辑器遵守根目录 `.editorconfig`。格式约定不等于完整静态分析；
后续引入 Lua/节点图代码时，需把其专项测试加入统一 check 入口。
fork PR 使用 GitHub-hosted Ubuntu；仓库内 PR 与推送使用本机专用标签。
checkout 不持久保存 GitHub token，工作流只授予 contents:read。

## 维护

```powershell
Get-Service 'actions.runner.CHNISam-Slay-the-Abyss.slay-the-abyss-windows'
gh api repos/CHNISam/Slay-the-Abyss/actions/runners
gh run list --repo CHNISam/Slay-the-Abyss --workflow quality.yml
```

停止服务前先确认 runner busy=false，且没有已分配的作业。
管理员 PowerShell 中可对上述精确服务名执行 Stop-Service / Start-Service。
不要操作其他仓库的服务，不读取或提交 runner 凭据文件。
本机必须开机联网才能接任务；重启后由服务自动恢复。
首次安装复用了本机现有官方 runner 2.337.0 的程序目录，未复制其凭据、
配置和工作目录；本项目使用独立注册令牌，保留官方自动更新机制。
直连下载 Actions 发生超时，因此仅在本 runner 的 `.env` 配置
`http_proxy` / `https_proxy` 为 `http://127.0.0.1:7897`（本机 Clash），
`no_proxy=localhost,127.0.0.1`。代理需保持可用；其他 runner 与全局代理未改动。

CI 只验证仓库逻辑与数据，不代表平台编译、写入存档或游戏内试玩通过。
CD 当前止于可审查的代码集成；正式游戏发布、赛事投稿由人完成。
2026-10-22 实查：GitHub 分支保护 API 返回 403，提示当前私有仓库套餐需
升级 GitHub Pro 才支持该功能。CI 会报告 check 结果，但服务端目前不能强制
阻止绕过检查合并；维护者须遵守先绿灯再合并，未改变套餐或仓库可见性。
