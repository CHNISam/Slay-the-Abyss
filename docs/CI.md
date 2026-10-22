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

并行的 presentation 作业在 GitHub-hosted Ubuntu 用系统 Python 跑文案回归
测试，不安装依赖。该测试包含符号链接，普通 Windows 服务账户缺少此权限；
保留完整测试而不扩大本机服务权限。合并前同时检查 check 与 presentation。

本地先 `npm ci --ignore-scripts`，再 `npm run check`。Lua同源测试使用锁定的
开发依赖Fengari；运行错误、语法错误、缺文件和超时均有非零退出回归。
Windows check作业先安装锁定开发依赖，再运行 `npm run check:rules`（Node+数据+Lua）；
Python表现测试由Ubuntu presentation作业完整执行。本地总入口仍包含两者。
check 作业直接使用已有 Git 与 Node（最低 22，本机 22.22.1），不下载
checkout/setup-node 组件。Git 精确检出事件提交 SHA，核对后清理 runner
工作目录；认证 header 仅在 fetch 进程环境中使用，随后清除，不写入磁盘配置。
编辑器遵守根目录 `.editorconfig`。格式约定不等于完整静态分析；
后续节点图检查继续加入统一入口；离线Lua测试与真机验证分别报告。
fork PR 使用 GitHub-hosted Ubuntu；仓库内 PR 与推送使用本机专用标签。
工作流只授予 contents:read；presentation 的标准 checkout 也不持久保存 token。

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
